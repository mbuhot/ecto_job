defmodule EctoJob.Mixfile do
  use Mix.Project

  @version "3.1.0"
  @url "https://github.com/mbuhot/ecto_job"

  def project do
    [
      app: :ecto_job,
      version: @version,
      elixir: "~> 1.10",
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
    [extra_applications: [:logger] ++ extra_applications(Mix.env())]
  end

  defp extra_applications(:test), do: [:postgrex]
  defp extra_applications(:test_myxql), do: [:myxql]
  defp extra_applications(_), do: []

  defp elixirc_paths(test) when test in [:test, :test_myxql], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      description: "A transactional job queue built with Ecto, PostgreSQL and GenStage.",
      licenses: ["MIT"],
      maintainers: ["Mike Buhot (m.buhot@gmail.com)"],
      links: %{
        "Changelog" => "https://hexdocs.pm/ecto_job/changelog.html",
        "Github" => @url
      }
    ]
  end

  defp dialyzer do
    [
      flags: ["-Werror_handling", "-Wno_unused", "-Wunmatched_returns", "-Wunderspecs"],
      # postgrex dep is optional: we want to ignore warnings for calling unknown
      # functions from this dep
      ignore_warnings: ".dialyzer.ignore-warnings.exs"
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md",
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @url,
      homepage_url: @url,
      formatters: ["html"]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.2"},
      {:postgrex, "~> 0.15", optional: true},
      {:myxql, "~> 0.2", optional: true},
      {:jason, "~> 1.0"},
      {:gen_stage, "~> 1.0"},
      {:credo, "~> 1.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: :dev, runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:inch_ex, "~> 2.0", only: :dev, runtime: false}
    ]
  end
end
