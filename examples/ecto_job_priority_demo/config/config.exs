# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger, :level, :info

config :ecto_job_priority_demo, ecto_repos: [EctoJobPriorityDemo.Repo]

config :ecto_job_priority_demo, EctoJobPriorityDemo.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "password",
  database: "ecto_job_test",
  hostname: "localhost",
  pool_size: 30

config :ecto_job,
  repo: EctoJobPriorityDemo.Repo,
  always_dispatch_jobs_on_poll: true,
  log: false
