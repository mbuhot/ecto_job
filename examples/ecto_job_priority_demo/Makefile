start_db:
	docker-compose -f docker-compose-test.yml up -d

migrate:
	@docker-compose -f docker-compose-test.yml run --rm dockerize dockerize -wait tcp://ecto-job-test:5432
	mix do ecto.create, ecto.migrate

run:
	iex -S mix
