defmodule LlamaApiWeb.V1.PageController do
  use LlamaApiWeb, :controller
  require Logger

  alias LlamaApi.Worker.{ LlamaWorker }

  def generate_text(conn, %{"prompt" => prompt}) do
    IO.inspect(prompt, label: "prompt")
    Task.start(fn -> 
      Logger.info("Starting task")
      result = GenServer.call(LlamaWorker, {:generate_text, prompt}, :infinity)

      case result do
        {:ok, generated_text} -> 
          Logger.info("Generated text: #{generated_text}")
        {:error, reason} -> 
          Logger.error("Error generating text: #{inspect(reason)}")
      end
    end)

    json conn, %{success: true, message: "Generating text"}
  end

  def ping(conn, _params) do
    # IO.inspect(conn, label: "conn")
    json conn, %{success: false}
  end

  def test(text) do
    IO.inspect(text, label: "text")
  end
end