defmodule AsyncJobApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      AsyncJobApi.Repo,
      {AsyncJobApi.JobQueue, repo: AsyncJobApi.Repo, max_demand: 10},
      {Registry, keys: :unique, name: AsyncJobApi.ConnRegistry},
      {AsyncJobApi.JobCompleteNotifier, name: AsyncJobApi.JobCompleteNotifier},
      {Plug.Adapters.Cowboy, scheme: :http, plug: AsyncJobApi.Router, options: [port: 9876]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: AsyncJobApi.Supervisor)
  end
end
