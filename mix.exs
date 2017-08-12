defmodule EctoJob.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ecto_job,
      version: "0.0.1",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env),
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [
      {:ecto, "~> 2.2-rc", override: true},
      {:postgrex, ">= 0.0.0"},
      {:gen_stage, ">= 0.0.0"}
    ]
  end
end
