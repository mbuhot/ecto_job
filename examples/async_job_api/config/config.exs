use Mix.Config

config :async_job_api, ecto_repos: [AsyncJobApi.Repo]

config :async_job_api, AsyncJobApi.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "password",
  database: "async_job_api",
  hostname: "localhost",
  pool_size: 10