defmodule AsyncJobApi.JobCompleteNotifier do
  use GenServer

  def start_link(name: name) do
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  def init(state) do
    pid = Process.whereis(AsyncJobApi.JobQueue.Notifier)
    Postgrex.Notifications.listen!(pid, "jobs.completed")
    {:ok, state}
  end

  def handle_info({:notification, _pid, _ref, "jobs.completed", payload}, state) do
    Registry.dispatch(AsyncJobApi.ConnRegistry, payload, fn [{pid, conn}] ->
      send(pid, {:job_completed, payload})
    end)
    {:noreply, state}
  end
end