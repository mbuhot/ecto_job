defmodule EctoJob.Producer do
  use GenStage
  alias EctoJob.JobQueue
  require Logger

  defmodule State do
    defstruct repo: nil, schema: nil, notifier: nil, demand: 0
  end

  def start_link(name: name, repo: repo, schema: schema, notifier: notifier) do
    GenStage.start_link(__MODULE__, %State{repo: repo, schema: schema, notifier: notifier}, name: name)
  end

  def init(state = %State{notifier: notifier, schema: schema}) do
    start_timer()
    start_listener(notifier, schema)
    {:producer, state}
  end

  defp start_timer() do
    :timer.send_interval(60_000, :poll)
  end

  defp start_listener(notifier, schema) do
    table_name = schema.__schema__(:source)
    Postgrex.Notifications.listen!(notifier, table_name)
  end

  def handle_info(_, state = %State{demand: 0}) do
    {:noreply, [], state}
  end
  def handle_info(:poll, state = %State{repo: repo, schema: schema}) do
    if activate_jobs(repo, schema, DateTime.utc_now()) > 0 do
      dispatch_jobs(state)
    else
      {:noreply, [], state}
    end
  end
  def handle_info({:notification, _pid, _ref, _channel, _payload}, state = %State{}) do
    dispatch_jobs(state)
  end

  def handle_demand(demand, state = %State{demand: buffered_demand}) do
    dispatch_jobs(%{state | demand: demand + buffered_demand})
  end

  defp activate_jobs(repo, schema, now = %DateTime{}) do
    JobQueue.activate_scheduled_jobs(repo, schema, now) +
    JobQueue.activate_expired_jobs(repo, schema, now)
  end

  defp dispatch_jobs(state = %State{repo: repo, schema: schema, demand: demand}) do
    {count, jobs} = JobQueue.reserve_available_jobs(repo, schema, demand, DateTime.utc_now())
    Logger.debug("Reserved #{count} jobs")
    {:noreply, jobs, %{state | demand: demand - count}}
  end
end
