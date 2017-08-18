defmodule EctoJob.WorkerSupervisor do
  @moduledoc """
  GenStage ConsumerSupervisor that will spawn `EctoJob.Worker` tasks for jobs.
  """

  import Supervisor.Spec
  alias EctoJob.Worker

  @doc """
  Starts the ConsumerSupervisor

   - `repo` : The Ecto.Repo module
   - `subscribe_opts` : Should contain [{producer_name, max_demand: max_demand}]
  """
  @spec start_link([repo: module, subscribe_to: Keyword.t]) :: Supervisor.on_start
  def start_link(repo: repo, subscribe_to: subscribe_opts) do
    children = [
      worker(Worker, [repo], restart: :temporary)
    ]
    ConsumerSupervisor.start_link(children, strategy: :one_for_one, subscribe_to: subscribe_opts)
  end
end
