# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

if Mix.env() == :test do
  config :ecto_job, EctoJob.Test.Repo,
    adapter: Ecto.Adapters.Postgres,
    username: "postgres",
    password: "password",
    database: "ecto_job_test",
    hostname: "localhost",
    pool: Ecto.Adapters.SQL.Sandbox,
    priv: "test/support/"

  config :ecto_job, ecto_repos: [EctoJob.Test.Repo]

  config :logger, level: :warn
end
