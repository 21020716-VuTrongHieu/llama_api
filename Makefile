# all: app

# Quy tắc để kiểm tra kết nối cơ sở dữ liệu
check-db:
	@echo "Checking database connection..."
	@mix run -e "LlamaApi.Repo.start_link() |> IO.inspect()"
	@mix run -e "Ecto.Adapters.SQL.query(LlamaApi.Repo, \"SELECT 1\", []) |> IO.inspect()"
	@echo "Database connection successful"


# Quy tắc để khởi động server và vào IEx
app:
	@echo "Creating Docker network if it does not exist..."
	docker network inspect llama_network >/dev/null 2>&1 || docker network create llama_network
	# @echo "Starting server and entering IEx..."
	docker rm -f llama-api-running-app || true
	docker-compose -f docker-compose.yml ${OTHER} run --name llama-api-running-app --use-aliases --rm -p 5001:5000 web iex -S mix phx.server
	# @mix phx.server & # Khởi động server ở chế độ nền
	# @sleep 5          # Đợi 5 giây để đảm bảo server đã khởi động (tuỳ chỉnh theo nhu cầu)
	# @iex -S mix       # Vào chế độ IEx và tải ứng dụng

build: 
	@echo "Building the app..."
	docker-compose build

bash:
	docker-compose run --rm web bash

stop: 
	@echo "Stopping the app..."
	docker-compose -f docker-compose.yml stop
	docker rm -f llama-api-running-app

logs: 
	@echo "Showing logs..."
	docker-compose logs -f

clean:
	@echo "Cleaning up..."
	docker-compose down -v
	docker volume prune -f
	docker network prune -f
