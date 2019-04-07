# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger, :level, :debug

config :ecto_job_demo, ecto_repos: [EctoJobDemo.Repo]

config :ecto_job_demo, EctoJobDemo.Repo,
  username: "postgres",
  password: "postgres",
  database: "ecto_job_demo",
  hostname: "localhost",
  pool_size: 10

# In dev/prod mode, configure the JobQueue to run on startup with 100 worker tasks max
# Note this config is used by the EctoJobDemo Application start callback, not the EctoJob library itself
config :ecto_job_demo, EctoJobDemo.JobQueue, repo: EctoJobDemo.Repo, max_demand: 100

# In test mode, the JobQueue is started from the tests themselves, after a connection
# has been checked out from the Sandbox pool
if Mix.env() == :test do
  config :logger, :level, :warn
  config :ecto_job_demo, EctoJobDemo.Repo, pool: Ecto.Adapters.SQL.Sandbox
  config :ecto_job_demo, EctoJobDemo.JobQueue, nil
end

config :exq,
  name: Exq,
  host: "127.0.0.1",
  namespace: "exq",
  concurrency: 100,
  queues: ["default"]
