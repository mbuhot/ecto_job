# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

{adapter, default_url} =
  case Mix.env() do
    :test ->
      {Ecto.Adapters.Postgres, "ecto://postgres:password@localhost/ecto_job_test"}

    :test_myxql ->
      {Ecto.Adapters.MyXQL, "ecto://root:mysql@localhost:13306/ecto_job_test"}

    _ ->
      {nil, nil}
  end

if adapter do
  config :ecto_job, EctoJob.Test.Repo,
    adapter: adapter,
    url: System.get_env("DB_URL", default_url),
    pool: Ecto.Adapters.SQL.Sandbox,
    priv: "test/support/"

  config :ecto_job, ecto_repos: [EctoJob.Test.Repo]

  config :logger, level: :warn
end
