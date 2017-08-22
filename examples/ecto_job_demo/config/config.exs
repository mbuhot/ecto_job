# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger, :level, :debug

config :ecto_job_demo, ecto_repos: [EctoJobDemo.Repo]

config :ecto_job_demo, EctoJobDemo.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "ecto_job_demo",
  hostname: "localhost",
  pool_size: 10
