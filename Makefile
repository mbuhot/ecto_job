compose:
	docker-compose -f docker-compose-test.yml up -d

db_setup:
	MIX_ENV=test mix do ecto.create, ecto.migrate

test: compose db_setup
	mix test
