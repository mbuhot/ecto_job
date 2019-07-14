defmodule EctoJobPriorityDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_job_priority_demo,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {EctoJobPriorityDemo.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_job, path: "../../"}
    ]
  end
end
