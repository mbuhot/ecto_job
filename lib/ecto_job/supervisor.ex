defmodule EctoJob.Supervisor do
  import Supervisor.Spec
  alias EctoJob.{Producer, WorkerSupervisor}

  def start_link(app: app, name: name, repo: repo, schema: schema, max_demand: max_demand) do
    repo_config = Application.get_env(app, repo)
    notifier_name = String.to_atom("#{name}Notifier")
    producer_name = String.to_atom("#{name}Producer")
    children = [
      worker(Postgrex.Notifications, [repo_config ++ [name: notifier_name]]),
      worker(Producer, [[name: producer_name, repo: repo, schema: schema, notifier: notifier_name]]),
      supervisor(WorkerSupervisor, [[repo: repo, subscribe_to: [{producer_name, max_demand: max_demand}]]])
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: name)
  end
end
