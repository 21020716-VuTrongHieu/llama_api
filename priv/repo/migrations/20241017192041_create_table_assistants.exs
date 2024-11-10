defmodule LlamaApi.Repo.Migrations.CreateTableAssistants do
  use Ecto.Migration

  def change do
    create table(:assistants, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string
      add :instructions, :string
      add :top_p, :float
      add :temperature, :float
      timestamps(type: :utc_datetime)
    end

    alter table(:threads) do
      add :assistant_id, :string
    end

    alter table(:process_runs) do
      add :assistant_id, :string
    end

    alter table(:conversations) do
      add :assistant_id, :string
    end
  end
end
