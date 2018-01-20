defmodule EctoJobDemo.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ecto_job_demo,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: EctoJobDemo.CLI]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {EctoJobDemo.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_job, path: "../../"},
      {:exq, ">= 0.0.0"}
    ]
  end
end
