defmodule LlamaApi.Repo.Migrations.CreateTableProcessRun do
  use Ecto.Migration

  def change do
    create table(:process_runs, primary_key: false) do
      add :id, :string, primary_key: true
      add :status, :string
      add :thread_id, :string
      add :started_at, :utc_datetime
      add :ended_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:process_runs, [:thread_id])
    create index(:process_runs, [:id, :thread_id])
  end
end
