defmodule LlamaApi.Rescue do
  use LlamaApiWeb, :controller

  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> render(LlamaApiWeb.ErrorView, "404.json")
  end

  def internal_server_error(conn, _params) do
    conn
    |> put_status(:internal_server_error)
    |> render(LlamaApiWeb.ErrorView, "500.json")
  end
end