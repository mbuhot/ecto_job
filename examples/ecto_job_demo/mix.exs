defmodule EctoJobDemo.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ecto_job_demo,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
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

  defp dialyzer do
    [
      flags: ["-Werror_handling", "-Wno_unused", "-Wunmatched_returns", "-Wunderspecs"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_job, path: "../../"},
      {:exq, ">= 0.0.0"},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false}
    ]
  end
end
