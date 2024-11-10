defmodule LlamaApi.Thread do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :status, :inserted_at, :updated_at]}
  @primary_key {:id, :string, autogenerate: false}
  schema "threads" do
    field :status, :string
    has_many :conversations, LlamaApi.Conversation
    belongs_to :assistant, LlamaApi.Assistant, type: :string

    timestamps()
  end

  @doc false
  def changeset(thread, attrs) do
    thread
    |> cast(attrs, [:id, :status, :assistant_id])
    |> put_change(:id, generate_thread_id())
  end

  defp generate_thread_id do 
    "thread_" <> Ecto.UUID.generate()
  end
end