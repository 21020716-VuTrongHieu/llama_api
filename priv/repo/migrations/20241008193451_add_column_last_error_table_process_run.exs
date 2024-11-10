defmodule LlamaApi.Repo.Migrations.AddColumnLastErrorTableProcessRun do
  use Ecto.Migration

  def change do
    alter table(:process_runs) do
      add :last_error, :string
    end
  end
end
