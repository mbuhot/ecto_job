defmodule AsyncJobApi.Mixfile do
  use Mix.Project

  def project do
    [
      app: :async_job_api,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {AsyncJobApi.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_job, path: "../../"},
      {:plug, "~> 1.4"},
      {:cowboy, "~> 1.0"}
    ]
  end
end
