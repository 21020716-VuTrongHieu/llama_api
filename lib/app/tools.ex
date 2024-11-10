defmodule LlamaApi.Tools do

  def add_prefix(value, length, prefix \\ "0") do
    cond do
      is_bitstring(value) ->
        if String.length(value) < length do
          value = prefix <> value
          add_prefix(value, length, prefix)
        else
          value
        end
      is_integer(value) -> add_prefix(Integer.to_string(value), length, prefix)
      true -> throw "Invalid value"
    end
  end

  def is_nil_or_empty?(nil), do: true
  def is_nil_or_empty?(""), do: true
  def is_nil_or_empty?([]), do: true
  def is_nil_or_empty?(%{} = map) do
    map
    |> Map.keys()
    |> length()
    |> Kernel.==(0)
  end

  def is_nil_or_empty?(_), do: false

  def enqueue(queue, payload) do
    r_channel = Application.get_env(:llama_api, :r_channel)
    task = Jason.encode!(payload)
    # :ok = AMQP.Confirm.select(r_channel)
    AMQP.Basic.publish r_channel, "", queue, task, persistent: true
    # receive do
    #   {:basic_ack, _delivery_tag, _multiple} ->
    #     IO.puts("Message has been confirmed by RabbitMQ!")
    #     :ok
    #   {:basic_nack, _delivery_tag, _multiple} ->
    #     IO.puts("Message was not confirmed by RabbitMQ.")
    #     :error
    # after
    #   5000 ->  # Timeout sau 5 giây nếu không có phản hồi
    #     IO.puts("No confirmation received within the timeout period.")
    #     :timeout
    # end
  end

  def enqueue_task_run(task) do
    queue = "wait_sec_03"
    enqueue(queue, task)
  end

  def get_botcake_host_name() do
    "http://botcake-host:4001/api/v1"
  end

  def get_botcake_secret() do
    "4j5iSAORv0vhb0W9eCcvDi47xdDXfD7i63_8B3eoaAdKsau6TUuWBZCdRrodduPr"
  end

  def http_post_json(url, data \\ %{}, err_msg \\ "Không thể thực hiện POST", headers \\ [], hackney_opts \\ []) do
    body = Jason.encode!(data)
    recv_timeout = Keyword.get(hackney_opts, :recv_timeout, 45_000)
    options = [recv_timeout: recv_timeout]
    options = if (url =~ "https"), do: options ++ [ssl: [{:versions, [:'tlsv1.2']}]], else: options
    hackney_opts = if String.match?(url, ~r/pages.fm/), do: hackney_opts ++ [insecure: true], else: hackney_opts
    options = if hackney_opts != [], do: options ++ [hackney: hackney_opts], else: options

    handle_http_response(HTTPoison.post(url, body, [{"Content-Type", "application/json"}] ++ headers, options), url, err_msg)
  end

  def handle_http_response(response, url, err_msg), do: handle_http_response(response, url, err_msg, 0)
  def handle_http_response(response, url, err_msg, _count, opts \\ []) do
    case response do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body, headers: headers}} ->
        is_gzipped = Enum.any?(headers, fn (kv) ->
          case kv do
            {"Content-Encoding", "gzip"} -> true
            {"Content-Encoding", "x-gzip"} -> true
            _ -> false
          end
        end)

        body = if is_gzipped, do: :zlib.gunzip(body) , else: body

        is_success = cond do
          status_code >= 200 and status_code < 300 -> true
          true -> false
        end

        response =
          case Jason.decode(body) do
            {:ok, response} -> response
            {:error, _}     ->
              if String.contains?(url, "https://graph.facebook.com/") do
                Rescue.convert_string_error_to_map(body)
              else
                body
              end
          end

          result = %{"success" => is_success, "response" => response, "status_code" => status_code}

        if Keyword.get(opts, :return_headers) do
          Map.put(result, "headers", headers)
        else
          result
        end
      {:error, %HTTPoison.Error{reason: reason}} ->

        %{
          "success" => false,
          "message" => reason || err_msg
        }
    end
  end

  def http_post_openai_stream(url, body, error_message \\ "Không thể thực hiện POST", headers) do
    case HTTPoison.post(url, Jason.encode!(body), [{"Content-Type", "application/json"}] ++ headers, stream_to: self()) do
      {:ok, %HTTPoison.AsyncResponse{id: id}} ->
        listen_for_openai_responses(id)
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp listen_for_openai_responses(id) do
    receive do
      %HTTPoison.AsyncStatus{id: ^id, code: code} ->
        listen_for_openai_responses(id)

      %HTTPoison.AsyncHeaders{id: ^id, headers: headers} ->
        listen_for_openai_responses(id)

      %HTTPoison.AsyncChunk{id: ^id, chunk: chunk} ->
        case Jason.decode(chunk) do
          {:ok, %{"error" => error}} ->
            {:error, %{success: true, error: error}}
      
          {:ok, %{"event" => "thread.message.completed", "data" => data}} ->
            {:ok, %{success: true, data: data}}
      
          {:error, _reason} ->
            case String.contains?(chunk, "event: thread.message.completed") do
              true ->
                [_, data] = String.split(chunk, "data: ")
                case Jason.decode(data) do
                  {:ok, decoded_data} ->
                    {:ok, %{success: true, data: decoded_data}}
                  {:error, reason} ->
                    listen_for_openai_responses(id)
                end
    
              false ->
                listen_for_openai_responses(id)
            end
          _ ->
            listen_for_openai_responses(id)
        end

      %HTTPoison.AsyncEnd{id: ^id} ->
        :ok
    after
      40_000 ->
        :timeout
    end
  end
  
end