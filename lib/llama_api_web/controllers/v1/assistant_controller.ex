defmodule LlamaApiWeb.V1.AssistantController do
  use LlamaApiWeb, :controller

  alias LlamaApi.{ Repo, Assistant, Tools , Thread, Conversation}
  import Ecto.Query

  @is_dev true

  def create(conn, params) do
    IO.inspect(params, label: "params")
    page_id = params["page_id"]
    body = 
      case params["body"] do
        nil -> %{}
        body -> body
      end
    
    name = body["name"] || page_id
    instructions = body["instructions"] || ""
    top_p = body["top_p"] || 0.9
    temperature = body["temperature"] || 0.6

    changeset = Assistant.changeset(%Assistant{}, %{
      name: name,
      instructions: instructions,
      top_p: top_p,
      temperature: temperature,
      page_id: page_id
    })

    case Repo.insert(changeset) do
      {:ok, assistant} ->
        json(conn, %{ success: true, assistant: assistant })
      {:error, changeset} ->
        json(conn, %{ success: false, errors: changeset.errors })
    end
  end

  def delete(conn, params) do
    assistant_id = params["assistant_id"]
    case Repo.get(Assistant, assistant_id) do
      nil -> 
        json(conn, %{ success: false, message: "Assistant not found" })
      assistant ->
        case Repo.delete(assistant) do
          {:ok, _} -> 
            json(conn, %{ success: true, assistant: assistant })
          {:error, _} -> 
            json(conn, %{ success: false, message: "Failed to delete assistant" })
        end
    end
  end

  def update(conn, params) do
    assistant_id = params["assistant_id"]
    case Repo.get(Assistant, assistant_id) do
      nil -> 
        json(conn, %{ success: false, message: "Assistant not found" })
      assistant ->
        body = 
          case params["body"] do
            nil -> %{}
            body -> body
          end
        name = body["name"] || assistant.name
        instructions = body["instructions"] || assistant.instructions
        top_p = body["top_p"] || assistant.top_p
        temperature = body["temperature"] || assistant.temperature

        changeset = Assistant.changeset(assistant, %{
          name: name,
          instructions: instructions,
          top_p: top_p,
          temperature: temperature
        })

        case Repo.update(changeset) do
          {:ok, assistant} ->
            json(conn, %{ success: true, assistant: assistant })
          {:error, changeset} ->
            json(conn, %{ success: false, errors: changeset.errors })
        end
    end
  end

  def list_assistants(conn, params) do
    page_id = params["page_id"]
    query = from(a in Assistant, where: a.page_id == ^page_id, select: a)
    assistants = Repo.all(query)
    json(conn, %{ success: true, assistants: assistants })
  end
end