defmodule LlamaApi.Repo.Migrations.CreateTableThreads do
  use Ecto.Migration

  def change do
    create table(:threads, primary_key: false) do
      add :id, :string, primary_key: true
      add :status, :string
      timestamps(type: :utc_datetime)
    end
  end
end
