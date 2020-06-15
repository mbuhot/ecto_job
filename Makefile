compose:
	docker-compose -f docker-compose-test.yml up -d

db_setup:
	@docker-compose -f docker-compose-test.yml run --rm dockerize dockerize -wait tcp://ecto-job-test:5432
	MIX_ENV=test mix do ecto.create, ecto.migrate

test: compose db_setup
	mix test
