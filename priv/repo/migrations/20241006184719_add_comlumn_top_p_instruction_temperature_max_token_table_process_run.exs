defmodule LlamaApi.Repo.Migrations.AddComlumnTopPInstructionTemperatureMaxTokenTableProcessRun do
  use Ecto.Migration

  def change do
    alter table(:process_runs) do
      add :top_p, :float, default: 0.9
      add :instruction, :string, default: ""
      add :temperature, :float, default: 0.6
      add :max_new_tokens, :integer, default: 256
    end
  end
end
