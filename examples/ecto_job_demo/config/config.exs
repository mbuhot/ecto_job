# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger, :level, :debug

config :ecto_job_demo, ecto_repos: [EctoJobDemo.Repo]

config :ecto_job_demo, EctoJobDemo.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "password",
  database: "ecto_job_demo",
  hostname: "localhost",
  pool_size: 10

config :exq,
  name: Exq,
  host: "127.0.0.1",
  namespace: "exq",
  concurrency: 100,
  queues: ["default"]
