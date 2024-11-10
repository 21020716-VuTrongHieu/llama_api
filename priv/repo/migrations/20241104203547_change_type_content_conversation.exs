defmodule LlamaApi.Repo.Migrations.ChangeTypeContentConversation do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      modify :content, :text
    end
  end
end
