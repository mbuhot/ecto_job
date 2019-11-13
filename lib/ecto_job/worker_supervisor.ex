defmodule EctoJob.WorkerSupervisor do
  @moduledoc """
  GenStage ConsumerSupervisor that will spawn `EctoJob.Worker` tasks for jobs.
  """

  import Supervisor.Spec
  alias EctoJob.{Config, Worker}

  @doc """
  Starts the ConsumerSupervisor

   - `config` : The JobQueue configuration, used for Repo, Logging options
   - `subscribe_opts` : Should contain [{producer_name, max_demand: max_demand}]
  """
  @spec start_link(config: Config.t(), subscribe_to: Keyword.t()) :: Supervisor.on_start()
  def start_link(config: config, subscribe_to: subscribe_opts) do
    children = [
      worker(Worker, [config], restart: :temporary)
    ]

    ConsumerSupervisor.start_link(children, strategy: :one_for_one, subscribe_to: subscribe_opts)
  end
end
