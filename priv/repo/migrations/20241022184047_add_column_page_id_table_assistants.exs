defmodule LlamaApi.Repo.Migrations.AddColumnPageIdTableAssistants do
  use Ecto.Migration

  def change do
    alter table(:assistants) do
      add :page_id, :string
    end

    create index(:assistants, [:page_id, :id])
  end
end
