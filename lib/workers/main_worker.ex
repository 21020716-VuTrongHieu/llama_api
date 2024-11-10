defmodule LlamaApi.Worker.MainWorker do
  use GenServer
  use AMQP
  alias LlamaApi.{ Tools }
  alias LlamaApi.Worker.{ ProcessRunWorker }


  def assign_job(chan, tag, _redelivered, payload) do
    task_uuid = Ecto.UUID.generate
    :ets.insert(:tasks_logger, {task_uuid, NaiveDateTime.utc_now, self(), payload})
    try do
      case Jason.decode payload do
        {:ok, obj} -> 

          case obj["action"] do
            nil                                       -> handle_nil_action(chan, tag ,obj)
            "pages:test"                              -> handle_test_action(chan, tag ,obj)
            "pages:process_run"                       -> ProcessRunWorker.process_run(obj)
            _                                         -> requeue_uncaught(chan, tag ,obj)
          end

          :ets.delete(:tasks_logger, task_uuid)
          Basic.ack chan, tag
        {:error, _} -> 
          :ets.delete(:tasks_logger, task_uuid)
          Basic.reject(chan, tag, requeue: false)
      end
    rescue
      exception -> 
        handle_rescue(task_uuid, chan, tag, payload, exception, inspect(System.stacktrace))
        reraise exception, System.stacktrace
    catch 
      :exit, exception -> 
        handle_rescue(task_uuid, chan, tag, payload, exception, inspect(System.stacktrace))
        reraise exception, System.stacktrace
      exception -> 
        handle_rescue(task_uuid, chan, tag, payload, exception, inspect(System.stacktrace))
        reraise exception, System.stacktrace
    end
  end

  defp handle_rescue(task_uuid, chan, tag, payload, exception, stacktrace) do
    # Logstash.log(%{
    #   key: "llama_api_task_pool_error",
    #   payload: payload,
    #   exception: exception,
    #   stacktrace: stacktrace,
    # })

    IO.puts "////////////////////////////////////////////////////////"
    IO.inspect payload
    IO.inspect exception
    IO.puts "////////////////////////////////////////////////////////"

    :ets.delete(:tasks_logger, task_uuid)

    # gửi task lỗi vào queue error để thử lại
    # Basic.publish(chan, "", "task_pool_error", payload, persistent: true)

    # thông báo xác nhận task đã xử lý xong
    # Basic.ack(chan, tag)

    # thông báo từ chối xử lý task và loại bỏ task khỏi queue
    Basic.reject(chan, tag, requeue: false)
  end

  def handle_nil_action(chan, task, obj) do
    IO.inspect(obj, label: "nil action obj:") 
    requeue_uncaught(chan, task, obj)
  end

  defp requeue_uncaught(chan, task, obj) do
    IO.inspect(obj, label: "uncaught obj:")
    Basic.reject(chan, task, requeue: false)
  end

  defp handle_test_action(chan, task, obj) do
    IO.inspect(obj, label: "test action obj:")
    Basic.ack(chan, task)
  end


  # def handle_test_action(chan, tag, obj) do
  #   try do
  #     Task.async(fn ->
  #       # Mã logic xử lý của tiến trình con
  #     end)
  #     |> Task.await(:infinity)
  #   rescue
  #     exception ->
  #       reraise exception, __STACKTRACE__
  #   end
  # end
end