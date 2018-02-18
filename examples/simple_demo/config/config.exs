use Mix.Config

config :simple_demo, ecto_repos: [SimpleDemo.Repo]

import_config "#{Mix.env}.exs"
