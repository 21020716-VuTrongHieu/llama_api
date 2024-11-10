defmodule LlamaApi.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversations" do
    field :content, :string
    field :status, :string
    field :role, Ecto.Enum, values: [:user, :assistant, :system], default: :user
    belongs_to :thread, LlamaApi.Thread, type: :string
    belongs_to :assistant, LlamaApi.Assistant, type: :string

    timestamps()
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:content, :status, :role, :thread_id, :assistant_id])
    |> validate_required([:thread_id])
    |> validate_inclusion(:role, [:user, :assistant, :system])
    |> cast_role()
  end

  defp cast_role(changeset) do
    case get_change(changeset, :role) do
      "user" -> put_change(changeset, :role, :user)
      "assistant" -> put_change(changeset, :role, :assistant)
      "system" -> put_change(changeset, :role, :system)
      _ -> changeset
    end
  end

end