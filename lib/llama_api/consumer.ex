defmodule LlamaApi.Consumer do
  use GenServer
  use AMQP
  alias LlamaApi.{ Tools, Worker }

  @queue              "task_pool"
  @error_queue        "task_pool_error"
  @retry_error_queue  "task_pool_error_retry"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    rabbitmq_connect()
  end

  defp perfetch_count(consuming_queue) do
    case consuming_queue do
      @queue -> 10
      @error_queue -> 5
      @retry_error_queue -> 5
      _ -> 2
    end
  end

  def rabbitmq_connect do
    username = Application.get_env(:amqp, :username) || "guest"
    password = Application.get_env(:amqp, :password) || "guest"
    host = Application.get_env(:amqp, :host) || "rabbitmq"
    port = Application.get_env(:amqp, :port) || 5672
    vhost = Application.get_env(:amqp, :vhost) || "m1"

    amqp_uri = "amqp://#{username}:#{password}@#{host}:#{port}/#{vhost}"

    IO.puts "Connecting to RabbitMQ at #{amqp_uri}"

    case Connection.open(amqp_uri) do
      {:ok, conn} ->
        IO.puts "Connected to RabbitMQ"

        Process.monitor(conn.pid)
        {:ok, chan} = Channel.open(conn)
        Process.monitor(chan.pid)

        case :ets.whereis(:tasks_logger) do
          :undefined -> :ets.new(:tasks_logger, [:named_table, :public])
          _ -> :ok
        end

        consuming_queue = @queue

        perfetch_count = perfetch_count(consuming_queue)

        Basic.qos(chan, prefetch_count: perfetch_count)

        Queue.declare(chan, @error_queue, durable: true, arguments: [
          {"x-dead-letter-exchange", :longstr, ""},
          {"x-dead-letter-routing-key", :longstr, @retry_error_queue},
          {"x-message-ttl", :signedint, 10000}
        ])

        [@queue, @retry_error_queue] 
        |> Enum.each(fn(queue) ->
          Queue.declare(chan, queue, durable: true, arguments: [
            {"x-dead-letter-exchange", :longstr, ""},
            {"x-dead-letter-routing-key", :longstr, @error_queue},
          ])
        end)

        seconds = (1..30 |> Enum.to_list) 
        Enum.each(seconds, &(
          Queue.declare(chan, "wait_sec_#{Tools.add_prefix(&1, 2)}", durable: true,
            arguments: [
              {"x-dead-letter-exchange", :longstr, ""},
              {"x-dead-letter-routing-key", :longstr, @queue},
              {"x-message-ttl", :signedint, &1 * 1000}
            ]
          )
        ))

        minutes = (1..30 |> Enum.to_list)
        Enum.each(minutes, &(
          Queue.declare(chan, "wait_min_#{Tools.add_prefix(&1, 2)}", durable: true,
            arguments: [
              {"x-dead-letter-exchange", :longstr, ""},
              {"x-dead-letter-routing-key", :longstr, @queue},
              {"x-message-ttl", :signedint, &1 * 60 * 1000}
            ]
          )
        ))

        hours = (1..24 |> Enum.to_list)
        Enum.each(hours, &(
          Queue.declare(chan, "wait_hour_#{Tools.add_prefix(&1, 2)}", durable: true,
            arguments: [
              {"x-dead-letter-exchange", :longstr, ""},
              {"x-dead-letter-routing-key", :longstr, @queue},
              {"x-message-ttl", :signedint, &1 * 60 * 60 * 1000}
            ]
          )
        ))

        {:ok, consumer_tag} = Basic.consume(chan, consuming_queue)

        IO.puts "Consuming from queue: #{consuming_queue}"
        Application.put_env(:llama_api, :r_channel, chan)
        Application.put_env(:llama_api, :r_consumer_tag, consumer_tag, persist: true)

        {:ok, chan}

      {:error, reason} ->
        IO.puts "Failed to connect to RabbitMQ: #{inspect(reason)}"
        IO.puts "Retrying in 5 seconds..."
        :timer.sleep(5000)
        # Process.sleep(5000)
        rabbitmq_connect()
    end
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, chan) do
    spawn fn -> Worker.MainWorker.assign_job(chan, tag, redelivered, payload) end
    {:noreply, chan}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, _) do
    IO.puts "Connection to RabbitMQ lost. Reconnecting..."
    {:ok, chan} = rabbitmq_connect()
    {:noreply, chan}
  end
end