defmodule EctoJobDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [EctoJobDemo.Repo] ++ job_queue_children()
    opts = [strategy: :one_for_one, name: EctoJobDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def job_queue_children() do
    case Application.get_env(:ecto_job_demo, EctoJobDemo.JobQueue) do
      nil -> []
      config -> [{EctoJobDemo.JobQueue, config}]
    end
  end
end
