defmodule LlamaApiWeb.PageController do
  use LlamaApiWeb, :controller

  def index(conn, _params) do
    json conn, %{success: false}
  end
end
