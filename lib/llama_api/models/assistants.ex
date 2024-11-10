defmodule LlamaApi.Assistant do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :name, :instructions, :top_p, :temperature, :inserted_at, :updated_at]}
  @primary_key {:id, :string, autogenerate: false}

  schema "assistants" do
    field :name, :string
    field :instructions, :string
    field :top_p, :float
    field :temperature, :float
    field :page_id, :string
    has_many :conversations, LlamaApi.Conversation
    has_many :threads, LlamaApi.Thread
    has_many :process_runs, LlamaApi.ProcessRun

    timestamps()
  end

  @doc false
  def changeset(assistant, attrs) do
    assistant
    |> cast(attrs, [:name, :instructions, :top_p, :temperature, :page_id])
    |> put_change(:id, generate_assistant_id())
  end

  defp generate_assistant_id do
    "asst_" <> Ecto.UUID.generate()
  end
end