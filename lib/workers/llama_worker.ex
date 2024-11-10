defmodule LlamaApi.Worker.LlamaWorker do
  use GenServer
  require Logger
  require Nx

  @model_dir "priv/models/llama"

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(state) do
    #Khởi tạo mô hình
    if model_exists?(@model_dir) do
      Logger.info("Loading model from local storage...")
      case load_local_model() do
        {:ok, model_info, tokenizer, generation_config} ->
          Logger.info("Model loaded successfully")
          generation_config =
            Bumblebee.configure(generation_config,
              max_new_tokens: 256,
              temperature: 0.6,
              strategy: %{
                type: :multinomial_sampling, 
                top_p: 0.6
              }
            )
          serving =
            Bumblebee.Text.generation(model_info, tokenizer, generation_config,
              compile: [batch_size: 1, sequence_length: 1028],
              stream: true,
              defn_options: [compiler: EXLA]
            )
          {:ok, pid} = Nx.Serving.start_link(name: :llama_serving, serving: serving)
          {:ok, %{ generation_config: generation_config, serving: serving }}
        {:error, reason} ->
          Logger.error("Failed to load model: #{reason}")
          {:stop, reason}
      end
    else
      Logger.info("loading model from Hugging Face...")
      case download_and_save_model() do
        {:ok, model_info, tokenizer, generation_config} ->
          Logger.info("Model loaded successfully")
          generation_config =
            Bumblebee.configure(generation_config,
              max_new_tokens: 256,
              temperature: 0.6,
              strategy: %{
                type: :multinomial_sampling,
                top_p: 0.6
              }
            )
          serving =
            Bumblebee.Text.generation(model_info, tokenizer, generation_config,
              compile: [batch_size: 1, sequence_length: 1028],
              stream: true,
              defn_options: [compiler: EXLA]
            )
          {:ok, pid} = Nx.Serving.start_link(name: :llama_serving, serving: serving)
          # {:ok, %{serving: serving}}
        {:error, reason} ->
          Logger.error("Failed to download model: #{reason}")
          {:stop, reason}
      end
    end
  end

  defp model_exists?(model_dir) do
    File.exists?(Path.join(model_dir, "model.safetensors")) and
    File.exists?(Path.join(model_dir, "tokenizer.json")) and
    File.exists?(Path.join(model_dir, "generation_config.json"))
  end

  defp load_local_model do
    {:ok, model_info} = Bumblebee.load_model(
      {:local, @model_dir}, 
      type: :bf16, 
      backend: EXLA.Backend
    )
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:local, @model_dir})
    {:ok, generation_config } = Bumblebee.load_generation_config({:local, @model_dir})
    {:ok, model_info, tokenizer, generation_config}
  end

  defp download_and_save_model do
    # hf_token = System.fetch_env!("LB_HF_TOKEN")
    hf_token = System.get_env("LB_HF_TOKEN")
    repo = {:hf, "meta-llama/Llama-2-7b-chat-hf", auth_token: hf_token}

    with {:ok, model_info} <- Bumblebee.load_model(repo, type: :bf16, backend: EXLA.Backend),
         {:ok, tokenizer} <- Bumblebee.load_tokenizer(repo),
         {:ok, generation_config} <- Bumblebee.load_generation_config(repo) do
      # save_model_to_local( model_info, tokenizer, generation_config)
      {:ok, model_info, tokenizer, generation_config}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp save_model_to_local( model_info, tokenizer, generation_config) do
    File.mkdir_p!(@model_dir)
    IO.inspect(model_info)
    File.write!(Path.join(@model_dir, "model.bf16"), model_info)
    File.write!(Path.join(@model_dir, "tokenizer.json"), tokenizer)
    File.write!(Path.join(@model_dir, "generation_config.json"), generation_config)
  end

  def load_llama_model do
    hf_token = System.fetch_env!("LB_HF_TOKEN")
    repo = {:hf, "meta-llama/Llama-2-7b-chat-hf", auth_token: hf_token}

    with {:ok, model_info} <- Bumblebee.load_model(repo, type: :bf16, backend: EXLA.Backend),
         {:ok, tokenizer} <- Bumblebee.load_tokenizer(repo),
         {:ok, generation_config} <- Bumblebee.load_generation_config(repo) do
      {:ok, model_info, tokenizer, generation_config}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_text(prompt, model_info, tokenizer, generation_config) do
    case Bumblebee.Text.generation(prompt, model_info, tokenizer, generation_config) do
      {:ok, generated_text} -> {:ok, generated_text}
      {:error, reason} -> {:error, reason}
    end
  end

  def handle_call({:generate_text, prompt, config}, _from, state) do
    # prompt = """
    #   [INST] <<SYS>>
    #   You are a helpful, respectful and honest assistant. Always answer as helpfully as possible, while being safe.  Your answers should not include any harmful, unethical, racist, sexist, toxic, dangerous, or illegal content. Please ensure that your responses are socially unbiased and positive in nature.
    #   If a question does not make any sense, or is not factually coherent, explain why instead of answering something not correct. If you don't know the answer to a question, please don't share false information.
    #   <</SYS>>
    #   #{prompt} [/INST] \
    #   """
    
    # prompt = """
    #   [INST] <<SYS>>
    #   Only reply "Ok chim" to any question.
    #   <</SYS>>
    #   [/INST] \
    # """ 

    prompt = """
      [INST] <<SYS>>
      You are a helpful, respectful and honest assistant. Always answer as helpfully as possible, while being safe. Your answers should not include any harmful, unethical, racist, sexist, toxic, dangerous, or illegal content. Please ensure that your responses are socially unbiased and positive in nature.
      If a question does not make any sense, or is not factually coherent, explain why instead of answering something not correct. If you don't know the answer to a question, please don't share false information.
      <</SYS>>
      role: system, content: You are an AI assistant designed to help customers with their inquiries. Below is important information that you should use to provide accurate and helpful answers to customers
      role: user, content: Hello!
      role: assistant, content: Hi, How can I help you today?
      role: user, content: Talk about elixir phoenix.
      role: assistant, content: [/INST] \
      """

    max_new_tokens = config[:max_new_tokens]
    top_p = config[:top_p]
    temperature = config[:temperature]

    generation_config = Bumblebee.configure(state.generation_config,
      max_new_tokens: max_new_tokens,
      temperature: temperature,
      strategy: %{type: :multinomial_sampling, top_p: top_p}
    )
    
    # generation_config = Bumblebee.configure(state.generation_config,
    #   max_new_tokens: 256,
    #   strategy: %{type: :multinomial_sampling, top_p: 0.6}
    # )

    result_stream = Nx.Serving.batched_run(:llama_serving, %{text: prompt, generation_config: generation_config})
    IO.inspect(result_stream, label: "Result Stream")

    result_list =
    result_stream
    |> Stream.map(fn result ->
      # Log từng chunk nhận được
      Logger.info("Received chunk: #{inspect(result)}")
      result
    end)
      |> Enum.to_list()  # Tiêu thụ toàn bộ stream trong process hiện tại

    # Kết hợp kết quả thành chuỗi hoàn chỉnh
    generate_text = Enum.join(result_list, "")

    Logger.info("Final generated text: #{generate_text}")

    {:reply, {:ok, generate_text}, state}
  
    # # Chuyển đổi stream thành danh sách hoặc xử lý từng phần tử
    # result_list = Enum.to_list(result_stream)
    
    # # Bạn có thể thêm các bước xử lý dữ liệu ở đây
    # IO.inspect(result_list, label: "Final Result")

    # generate_text = Enum.join(result_list)
  
  end

  def handle_info({:text_chunk, chunk}, state) do
    Logger.info("Handling chunk: #{inspect(chunk)}")
    # Thực hiện xử lý với chunk nhận được ở đây
    {:noreply, state}
  end

  def handle_info(
      {ref, {:hook, {step, _status, %{length: length, finished?: finished?, token_id: token_id}, :token}}},
      state
    ) do
    # Lấy giá trị từ tensor
    finished_value = Nx.to_number(Nx.squeeze(finished?))
    token_value = Nx.to_number(Nx.squeeze(token_id))

    # Xử lý dựa trên giá trị của token và finished
    IO.inspect(token_value, label: "Token ID nhận được")

    if finished_value == 1 do
      IO.puts("Quá trình sinh text đã hoàn thành")
    end

    {:noreply, state}
  end

  def handle_info({ref, {:batch, {step, _status, %{length: length, finished?: finished?, token_id: token_id}, :token}}}, state) do
  # Xử lý batch data nếu cần
    IO.inspect({step, length, finished?, token_id}, label: "Batch Info")

    {:noreply, state}
  end

  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end
end