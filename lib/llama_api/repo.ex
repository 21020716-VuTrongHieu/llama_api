defmodule LlamaApi.Repo do
  use Ecto.Repo,
    otp_app: :llama_api,
    adapter: Ecto.Adapters.Postgres
end
