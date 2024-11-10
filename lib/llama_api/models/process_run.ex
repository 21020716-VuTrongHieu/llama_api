defmodule LlamaApi.ProcessRun do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :status, :started_at, :ended_at, :instruction, :top_p, :temperature, :max_new_tokens, :thread_id, :inserted_at, :updated_at, :last_error, :assistant_id]}
  @primary_key {:id, :string, autogenerate: false}
  schema "process_runs" do
    field :status, :string
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :instruction, :string
    field :top_p, :float
    field :temperature, :float
    field :max_new_tokens, :integer
    field :last_error, :string

    belongs_to :thread, LlamaApi.Thread, type: :string
    belongs_to :assistant, LlamaApi.Assistant, type: :string

    timestamps()
  end

  @doc false
  def changeset(process_run, attrs) do
    process_run
    |> cast(attrs, [:status, :thread_id, :started_at, :ended_at, :instruction, :top_p, :temperature, :max_new_tokens, :last_error, :assistant_id])
    |> validate_required([:thread_id])
    |> put_change(:id, generate_process_run_id())
  end

  defp generate_process_run_id do
    "run_" <> Ecto.UUID.generate()
  end
end