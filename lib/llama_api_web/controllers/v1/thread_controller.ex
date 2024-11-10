defmodule LlamaApiWeb.V1.ThreadController do
  use LlamaApiWeb, :controller

  alias LlamaApi.{ Repo, Thread, Conversation, Tools }
  import Ecto.Query

  def create(conn, params) do
    IO.inspect(params, label: "params")
    body = 
      case params["body"] do
        nil -> %{}
        body -> body
      end
    list_conversation = body["list_conversation"] || []
    IO.inspect(list_conversation, label: "list_conversation")
    assistant = body["assistant"]

    IO.inspect(assistant, label: "assistant")

    changeset = Thread.changeset(%Thread{}, %{
      status: "open",
      assistant_id: assistant["id"],
    })

    case Repo.insert(changeset) do
      {:ok, thread} ->
        if !Tools.is_nil_or_empty?(list_conversation) do
          Enum.each(list_conversation, fn conversation ->
            conversation_changeset = Conversation.changeset(%Conversation{}, %{
              thread_id: thread.id,
              role: conversation["role"],
              content: conversation["content"]
            })
            Repo.insert(conversation_changeset)
          end)
        end

        json(conn, %{ success: true, thread: thread })
      {:error, changeset} ->
        json(conn, %{ success: false, errors: changeset.errors })
    end
  end

  def delete(conn, params) do
    thread_id = params["thread_id"]
    case Repo.get(Thread, thread_id) do
      nil -> 
        json(conn, %{ success: false, message: "Thread not found" })
      thread ->
        case Repo.delete(thread) do
          {:ok, _} -> 
            from(c in Conversation, where: c.thread_id == ^thread_id)
            |> Repo.delete_all()
            json(conn, %{ success: true, thread: thread })
          {:error, _} -> 
            json(conn, %{ success: false, message: "Failed to delete thread" })
        end
    end
  end

  def messages(conn, params) do
    thread_id = params["thread_id"]
    case Repo.get(Thread, thread_id) do
      nil -> 
        json(conn, %{ success: false, message: "Thread not found" })
      thread ->
        conversations = 
          from(c in Conversation, where: c.thread_id == ^thread_id, order_by: [desc: c.id])
          |> Repo.all()
          |> Enum.map(fn conversation ->
            %{
              id: conversation.id,
              role: conversation.role,
              content: conversation.content,
              inserted_at: conversation.inserted_at
            }
          end)
        json(conn, %{ success: true, thread: thread, conversations: conversations })
    end
  end

  def create_message(conn, params) do
    IO.inspect(params, label: "params")
    thread_id = params["thread_id"]
    body = 
      case params["body"] do
        nil -> %{}
        body -> body
      end
    assistant_id = body["assistant_id"]
    list_conversation = body["list_conversation"] || %{}
    IO.inspect(list_conversation, label: "list_conversation")
    case Repo.get(Thread, thread_id) do
      nil -> 
        json(conn, %{ success: false, message: "Thread not found" })
      thread ->
        if !Tools.is_nil_or_empty?(list_conversation) do
          case Repo.transaction(fn ->
            Enum.map(list_conversation, fn conversation -> 
              changeset = Conversation.changeset(%Conversation{}, %{
                thread_id: thread.id,
                role: conversation["role"],
                content: conversation["content"],
                assistant_id: assistant_id
              })

              case Repo.insert(changeset) do
                {:ok, _} -> 
                  {:ok, nil}
                {:error, changeset} -> 
                  Repo.rollback(changeset.errors)
              end
            end)
          end) do
            {:ok, _} -> 
              json(conn, %{ success: true, thread: thread })
            {:error, errors} ->
              IO.inspect(errors, label: "errors")
              json(conn, %{ success: false, message: format_errors(errors) })
          end
        else
          json(conn, %{ success: false, message: "No conversation to create" })
        end
    end
  end

  def show(conn, params) do
    thread_id = params["thread_id"]
    case Repo.get(Thread, thread_id) do
      nil -> 
        json(conn, %{ success: false, message: "Thread not found" })
      thread ->
        json(conn, %{ success: true, thread: thread })
    end
  end

  defp format_errors(errors) do
    Enum.map(errors, fn {field, {message, _opts}} ->
      "#{field} #{message}"
    end)
  end

end