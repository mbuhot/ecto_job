use Mix.Config

# Configure your database
config :simple_demo, SimpleDemo.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "simple_demo_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
