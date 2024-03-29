defmodule EctoJob.Supervisor do
  @moduledoc """
  Job Queue supervisor that can be started with client applications.

  The `EctoJob.Supervisor` will start the required processes to listen for postgres job notifications,
  GenStage producer and ConsumerSupervisor to process the jobs.

  ## Examples

      def start(_type, _args) do
        import Supervisor.Spec

        children = [
          supervisor(MyApp.Repo, []),
          supervisor(MyApp.Endpoint, []),
          supervisor(EctoJob.Supervisor, [[
            name: MyAppJobQueue,
            app: :my_app,
            repo: MyApp.Repo,
            schema: MyApp.JobQueue,
            max_demand: 100]])
        ]

        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end

  """

  import Supervisor.Spec, only: [worker: 2, supervisor: 2]
  alias EctoJob.{Config, Producer, WorkerSupervisor}

  @doc """
  Starts an EctoJob queue supervisor.
  """
  @spec start_link(Config.t()) :: {:ok, pid}
  def start_link(
        config = %Config{
          repo: repo,
          schema: schema,
          max_demand: max_demand,
          poll_interval: poll_interval,
          reservation_timeout: reservation_timeout,
          execution_timeout: execution_timeout,
          notifications_listen_timeout: notifications_listen_timeout
        }
      ) do
    supervisor_name = String.to_atom("#{schema}.Supervisor")
    producer_name = String.to_atom("#{schema}.Producer")

    {children, notifier_name} =
      case repo.__adapter__() do
        Ecto.Adapters.Postgres ->
          notifier_name = String.to_atom("#{schema}.Notifier")

          {[worker(Postgrex.Notifications, [repo.config() ++ [name: notifier_name]])],
           notifier_name}

        _ ->
          {[], nil}
      end

    children =
      children ++
        [
          worker(Producer, [
            [
              name: producer_name,
              repo: repo,
              schema: schema,
              notifier: notifier_name,
              poll_interval: poll_interval,
              reservation_timeout: reservation_timeout,
              execution_timeout: execution_timeout,
              notifications_listen_timeout: notifications_listen_timeout
            ]
          ]),
          supervisor(WorkerSupervisor, [
            [config: config, subscribe_to: [{producer_name, max_demand: max_demand}]]
          ])
        ]

    Supervisor.start_link(children, strategy: :rest_for_one, name: supervisor_name)
  end
end
