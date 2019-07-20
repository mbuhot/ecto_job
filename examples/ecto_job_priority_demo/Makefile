start_db:
	docker-compose -f docker-compose-test.yml up -d

migrate:
	mix do ecto.create, ecto.migrate

run:
	iex -S mix
