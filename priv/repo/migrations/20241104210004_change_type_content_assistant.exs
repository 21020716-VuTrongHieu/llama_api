defmodule LlamaApi.Repo.Migrations.ChangeTypeContentAssistant do
  use Ecto.Migration

  def change do
    alter table(:assistants) do
      modify :instructions, :text
    end

    alter table(:process_runs) do
      modify :instruction, :text
    end
  end
end
