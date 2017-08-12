defmodule EctoJob.WorkerSupervisor do
  import Supervisor.Spec
  alias EctoJob.Worker

  def start_link(repo: repo, subscribe_to: subscribe_opts) do
    ConsumerSupervisor.start_link(
      [worker(Worker, [repo], restart: :temporary)],
      strategy: :one_for_one,
      subscribe_to: subscribe_opts)
  end
end
