defmodule LlamaApiWeb.V1.ProcessRunController do
  use LlamaApiWeb, :controller
  require Logger
  import Ecto.Query

  alias LlamaApi.{ Repo, ProcessRun, Conversation, Tools }

  def create(conn, params) do
    thread_id = params["thread_id"]
    body = 
      case params["body"] do
        nil -> %{}
        body -> body
      end

    page_id = params["page_id"]
    psid = params["psid"]

    IO.inspect(body, label: "body")
    instruction = body["instructions"] || ""
    additional_messages = body["additional_messages"] || []
    top_p = body["top_p"] || 0.9
    temperature = body["temperature"] || 0.6
    max_new_tokens = body["max_completion_tokens"] || 256
    assistant_id = body["assistant_id"]

    {add_message_status, add_message_content} = if !Tools.is_nil_or_empty?(additional_messages) do
      case Repo.transaction(fn ->
        Enum.each(additional_messages, fn message ->
          message_changeset = Conversation.changeset(%Conversation{}, %{
            thread_id: thread_id,
            role: message["role"],
            content: message["content"],
            assistant_id: assistant_id
          })

          case Repo.insert(message_changeset) do
            {:ok, _} -> 
              {:ok, nil}
            {:error, changeset} -> 
              Repo.rollback(changeset.errors)
          end
        end)
      end) do
        {:ok, _} -> 
          {:ok, nil}
        {:error, errors} -> 
          {:error, format_errors(errors)}
      end
    else 
      {:ok, nil}
    end

    if add_message_status == :ok do

      IO.inspect(assistant_id, label: "assistant_id")
      run_changeset = ProcessRun.changeset(%ProcessRun{}, %{
        thread_id: thread_id,
        instruction: instruction,
        top_p: top_p,
        temperature: temperature,
        max_new_tokens: max_new_tokens,
        status: "queued",
        assistant_id: assistant_id
      })

      case Repo.insert(run_changeset) do
        {:ok, run} -> 
          task = %{
            action: "pages:process_run",
            run_id: run.id,
            thread_id: thread_id,
            instruction: instruction,
            top_p: top_p,
            temperature: temperature,
            max_new_tokens: max_new_tokens,
            assistant_id: assistant_id,
            page_id: page_id,
            psid: psid
          }

          Tools.enqueue_task_run(task)
          json(conn, %{ success: true, run: run })
        {:error, changeset} -> 
          json(conn, %{ success: false, errors: changeset.errors })
      end
    else
      json(conn, %{ success: false, errors: add_message_content })
    end
  end

  def show(conn, params) do
    run_id = params["run_id"]
    thread_id = params["thread_id"]
    run = from(
      p in ProcessRun, 
      where: p.id == ^run_id and p.thread_id == ^thread_id, 
      select: p
    )
    |> Repo.one()

    if run do
      json(conn, %{ success: true, run: run })
    else
      json(conn, %{ success: false, message: "Run not found" })
    end
  end

  defp format_errors(errors) do
    Enum.map(errors, fn {field, {message, _opts}} ->
      "#{field} #{message}"
    end)
  end
end
