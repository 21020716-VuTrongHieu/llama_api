defmodule LlamaApi.Repo.Migrations.CreateTableConversation do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :thread_id, :string
      add :role, :string
      add :content, :string
      add :status, :string
      timestamps(type: :utc_datetime)
    end

    create index(:conversations, [:thread_id])
    create index(:conversations, [:thread_id, :role])
  end
end
