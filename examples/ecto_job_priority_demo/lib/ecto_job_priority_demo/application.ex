defmodule EctoJobPriorityDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {EctoJobPriorityDemo.Repo, []},
      {EctoJobPriorityDemo.JobQueue, [repo: EctoJobPriorityDemo.Repo, max_demand: 100]},
      {EctoJobPriorityDemo, %{}}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EctoJobPriorityDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
