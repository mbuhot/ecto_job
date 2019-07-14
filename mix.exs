defmodule EctoJob.Mixfile do
  use Mix.Project

  @version "3.0.0"
  @url "https://github.com/mbuhot/ecto_job"

  def project do
    [
      app: :ecto_job,
      description: "A transactional job queue built with Ecto, PostgreSQL and GenStage.",
      version: @version,
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Mike Buhot (m.buhot@gmail.com)"],
      links: %{
        "Github" => @url
      }
    ]
  end

  defp dialyzer do
    [
      flags: ["-Werror_handling", "-Wno_unused", "-Wunmatched_returns", "-Wunderspecs"]
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @url,
      homepage_url: @url
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {:postgrex, "~> 0.14"},
      {:jason, "~> 1.0"},
      {:gen_stage, "~> 0.13"},
      {:credo, "~> 1.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:ex_doc, "~> 0.12", only: :dev, runtime: false},
      {:inch_ex, ">= 0.4.0", only: :dev, runtime: false}
    ]
  end
end
