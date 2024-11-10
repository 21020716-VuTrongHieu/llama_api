defmodule LlamaApi.Worker.ProcessRunWorker do
  use GenServer
  require Logger

  alias LlamaApi.{ Repo, ProcessRun, Conversation, Tools }
  alias LlamaApi.Worker.{ LlamaWorker }

  import Ecto.Query

  def process_run(obj) do
    Logger.info("Processing run")
    run_id = obj["run_id"]
    thread_id = obj["thread_id"]
    assistant_id = obj["assistant_id"]
    instruction = obj["instruction"] || ""
    token = obj["token"]
    top_p = obj["top_p"] || 0.9
    temperature = obj["temperature"] || 0.6
    max_new_tokens = obj["max_new_tokens"] || 256
    additional_messages = obj["additional_messages"] || []
    page_id = obj["page_id"]
    psid = obj["psid"]

    IO.inspect(obj, label: "obj______________________")

    query = from(pr in ProcessRun, where: pr.id == ^run_id)
    exited_run = Repo.one(query)
    process_generate_text = Ecto.Changeset.change(exited_run, %{
      status: "in_progress",
      started_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
    |> case do
      {:ok, _} -> 
        Logger.info("Run status updated")
        conversations_history = get_list_of_conversations(thread_id)
        last_conversation = List.last(conversations_history)
        conversations_history = if true, do: conversations_history |> Enum.drop(-1), else: conversations_history  # Remove the last conversation nhớ sửa lại
        prompt = if !Tools.is_nil_or_empty?(conversations_history) do
          Enum.reduce(conversations_history, "", fn conversation, acc -> 
            acc <> "role: #{conversation.role}, content: #{conversation.content}\n"
          end)
        else
          ""
        end

        prompt = if !Tools.is_nil_or_empty?(additional_messages) do
          Enum.reduce(additional_messages, prompt, fn message, acc -> 
            acc <> "role: #{message["role"]}, content: #{message["content"]}\n"
          end)
        else
          prompt
        end
        prompt = instruction <> "Acting as an assistant, continue to complete the following conversation:\n\n" <> prompt # tạm cmt đoạn này lại <> "role: assistant, content:"
        IO.inspect(prompt, label: "prompt")
        # {:ok, _} = GenServer.call(LlamaWorker, {:generate_text, prompt}, :infinity)

        task = Task.async(fn -> 
          if false do
            GenServer.call(LlamaWorker, {:generate_text, prompt, %{top_p: top_p, temperature: temperature, max_new_tokens: max_new_tokens}}, :infinity)
          else
            last_additional_messages = last_conversation

            IO.inspect(last_additional_messages, label: "last_additional_messages")

            last_content = if last_additional_messages do
              last_additional_messages.content
            else
              nil
            end
            IO.inspect(last_content, label: "last_content")
            response = call_open_ai(prompt, last_content, top_p, temperature, max_new_tokens)
            IO.inspect(response, label: "response")
            response
          end
        end)

        result = case Task.yield(task, 30_000) || Task.shutdown(task) do
            {:ok, response} -> response
            nil -> 
              Logger.error("Task timed out after 1000 ms")
              {:error, "Timeout"}
            {:exit, reason} ->
              Logger.error("Task failed with reason: #{inspect(reason)}")
              {:error, reason}
          end
        IO.inspect(result, label: "result______________________")
        case result do
          {:ok, generated_text} -> 
            Logger.info("Generated text: #{generated_text}")
            Ecto.Changeset.change(exited_run, %{
              status: "completed",
              ended_at: DateTime.utc_now() |> DateTime.truncate(:second)
            })
            |> Repo.update()
            |> case do
              {:ok, _} -> 
                Logger.info("Run status updated")
                Conversation.changeset(%Conversation{}, %{
                  thread_id: thread_id,
                  role: "assistant",
                  content: generated_text,
                  assistant_id: assistant_id
                })
                |> Repo.insert()
                |> case do
                  {:ok, _} -> 
                    Logger.info("Generated text inserted")
                    {:ok, generated_text}
                  _ -> 
                    Logger.error("Failed to insert generated text")
                    {:error, "Failed to insert generated text"}
                end
              {:error, _} -> 
                Logger.error("Failed to update run status")
                {:error, "Failed to update run status"}
            end
          {:error, reason} -> 
            Logger.error("Error generating text: #{inspect(reason)}")
            Ecto.Changeset.change(exited_run, %{
              status: "failed",
              ended_at: DateTime.utc_now() |> DateTime.truncate(:second),
              last_error: reason
            })
            |> Repo.update()
            |> case do
              {:ok, _} -> 
                Logger.info("Run status updated")
                {:error, reason}
              {:error, _} -> 
                Logger.error("Failed to update run status")
                {:error, "Failed to update run status"}
            end
        end
      _ ->
        Logger.error("Failed to update run status")
        {:error, "Failed to update run status"}
    end

    handle_http_call(process_generate_text, obj)
  end

  defp handle_http_call(process_generate_text, obj) do
    case process_generate_text do
      {:ok, generate_text} -> 
        Logger.info("Process generate text success")

        IO.inspect(obj, label: "obj______________________")
        url_botcake = "#{Tools.get_botcake_host_name()}/pages/#{obj["page_id"]}/process_run_callback_llama"
        botcake_secret = Tools.get_botcake_secret
        data = %{
          success: true,
          secret_key: botcake_secret,
          run_id: obj["run_id"],
          thread_id: obj["thread_id"],
          assistant_id: obj["assistant_id"],
          page_id: obj["page_id"],
          psid: obj["psid"],
          generate_text: generate_text
        }

        IO.inspect(Tools.http_post_json(url_botcake, data, "Không thể thực hiện POST"), label: "data______________________")

        case Tools.http_post_json(url_botcake, data, "Không thể thực hiện POST") do
          %{"success" => true} -> 
            Logger.info("Call api to Botcake success")
          _ -> 
            Logger.error("Call api to Botcake failed")
        end
      {:error, reason} -> 
        Logger.error("Process generate text failed: #{inspect(reason)}")
        botcake_secret = Tools.get_botcake_secret
        data = %{
          success: false,
          secret_key: botcake_secret,
          run_id: obj["run_id"],
          thread_id: obj["thread_id"],
          assistant_id: obj["assistant_id"],
          page_id: obj["page_id"],
          psid: obj["psid"],
          last_error: reason
        }

        case Tools.http_post_json("#{Tools.get_botcake_host_name()}/pages/#{obj["page_id"]}/process_run_callback_llama", data, "Không thể thực hiện POST") do
          %{"success" => true} -> 
            Logger.info("Call api to Botcake success")
          _ -> 
            Logger.error("Call api to Botcake failed")
        end
        {:error, "Process generate text failed"}
    end
  end

  defp call_open_ai(prompt, request, top_p, temperature, max_completion_tokens) do
    Logger.info("Call open ai")
    token = System.get_env("OPENAI_API_KEY")
    assistant_id = System.get_env("ASSISTANT_ID")
    headers_assistants = [{"authorization", "Bearer #{token}"}, {"OpenAI-Beta", "assistants=v2"}]

    body_create_answer = %{
      "assistant_id" => assistant_id,
      "instructions" => prompt,
      "max_completion_tokens" => max_completion_tokens,
      "temperature" => temperature,
      "top_p" => top_p,
      "thread" => %{
        "messages" => [
          %{
            "role" => "user",
            "content" => request
          }
        ]
      },
      "stream" => true
    }

    http_create_answer = Tools.http_post_openai_stream("https://api.openai.com/v1/threads/runs", body_create_answer, "Không thể thực hiện POST", headers_assistants)
    IO.inspect(http_create_answer, label: "http_create_answer")
    case http_create_answer do
      {:ok, %{success: true, data: response_data}} ->
        content = response_data["content"]
        first_content = List.first(content)
        value = first_content["text"]["value"]
        IO.inspect(value, label: "value")
        {:ok, value}
      {:error, %{success: true, error: error}} ->
        reason = error["message"]
        {:error, reason}
      :timeout ->
        {:error, "Timeout"}
      _ ->
        {:error, "Failed to create answer"}
    end
  end

  def get_list_of_conversations(thread_id, limit \\ 20) do
    from(c in Conversation, where: c.thread_id == ^thread_id, limit: ^limit, order_by: [desc: c.id])
    |> Repo.all()
    |> Enum.reverse()
    |> Enum.map(fn conversation -> 
      %{
        id: conversation.id,
        role: conversation.role,
        content: conversation.content,
        created_at: conversation.inserted_at
      }
    end)
  end

  defp black_box(token, assistant_id, thread_id, additional_messages, instructions, top_p, temperature, max_new_tokens) do
    Logger.info("Black box")
    # Do something

    headers_assistants = [{"authorization", "Bearer #{token}"}, {"OpenAI-Beta", "assistants=v2"}]
    body_create_answer = %{
      "assistant_id" => assistant_id,
      "instructions" => instructions,
      "max_completion_tokens" => max_new_tokens,
      "top_p" => top_p,
      "temperature" => temperature,
      "additional_messages" => additional_messages
    }

    http_run_answer = Tools.http_post_json("https://api.openai.com/v1/threads/#{thread_id}/runs", body_create_answer, "Không thể thực hiện POST", headers_assistants)

    case http_run_answer["success"] do
      true -> 
        response = http_run_answer["response"]
        result = case response["status"] do
          "completed" -> true
          "queued" -> check_run_status_open_ai(thread_id, response["id"], headers_assistants, 5)
          _ -> nil
        end

        case result do
          true -> 
            http_messages = Tools.http_get("https://api.openai.com/v1/threads/#{thread_id}/messages", "Không thể thực hiện GET", 45000, headers_assistants)
            case http_messages["success"] do
              true -> 
                response = http_messages["response"]
                first_message = List.first(response["data"])
                content = if first_message, do: List.first(first_message["content"])
                reply_message = if content && content["type"] == "text", do: content["text"]["value"]
                {:ok, reply_message}
              _ -> {:error, "Failed to get messages"}
            end
          _ -> {:error, "Failed to create answer"}
        end
      _ -> {:error, "Failed to create answer"}
    end

    {:ok, "Black box"}
  end

  defp check_run_status_open_ai(thread_id, run_id, headers_assistants, retries) do
    if retries > 0 do
      http_call = Tools.http_get("https://api.openai.com/v1/threads/#{thread_id}/runs/#{run_id}", "Không thể thực hiện GET", 45000, headers_assistants)
      case http_call["success"] do
        true ->
          response = http_call["response"]
          case response["status"] do
            "completed" -> true
            "failed" -> nil
            _ ->
              Process.sleep(2000)
              check_run_status_open_ai(thread_id, run_id, headers_assistants, retries - 1)
          end
        _ -> nil
      end
    end
  end
end