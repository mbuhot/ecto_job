defmodule EctoJobPriorityDemo do
  @moduledoc false
  use GenServer

  alias EctoJobPriorityDemo.JobMonitor
  alias EctoJobPriorityDemo.JobQueue
  alias EctoJobPriorityDemo.Repo

  require Logger

  @high_priority 0
  @regular_priority 1
  @low_priority 2

  def start_link(jobs \\ %{}) do
    GenServer.start_link(__MODULE__, jobs, name: __MODULE__)
  end

  def init(_) do
    period = 5000
    count = 500

    {:ok, low_priority} =
      JobMonitor.start_link(
        %{count: count, priority: @low_priority, period: period},
        :low_priority
      )

    {:ok, regular_priority} =
      JobMonitor.start_link(
        %{count: count, priority: @regular_priority, period: period},
        :regular_priority
      )

    {:ok, high_priority} =
      JobMonitor.start_link(
        %{count: count, priority: @high_priority, period: period},
        :high_priority
      )

    state = %{
      high_priority: high_priority,
      regular_priority: regular_priority,
      low_priority: low_priority
    }

    Logger.info("Jobs monitor started")

    send(self(), {:notify_jobs})
    {:ok, state}
  end

  def resolve(priority) do
    GenServer.cast(__MODULE__, {:resolve, priority})
  end

  # Server

  def handle_info({:notify_jobs}, state) do
    %{
      high_priority: high_priority,
      regular_priority: regular_priority,
      low_priority: low_priority
    } = state

    high_priority_value =
      high_priority
      |> JobMonitor.count()

    regular_priority_value =
      regular_priority
      |> JobMonitor.count()

    low_priority_value =
      low_priority
      |> JobMonitor.count()

    Logger.info(
      "high_priority: #{inspect(high_priority_value)}, regular_priority: #{
        inspect(regular_priority_value)
      }, low_priority: #{inspect(low_priority_value)}"
    )

    Process.send_after(self(), {:notify_jobs}, 100)
    {:noreply, state}
  end

  def handle_cast({:resolve, priority}, state) do
    state
    |> update_jobs(priority, -1)

    {:noreply, state}
  end

  defp update_jobs(%{high_priority: high_priority}, @high_priority, value) do
    high_priority
    |> JobMonitor.update(value)
  end

  defp update_jobs(%{regular_priority: regular_priority}, @regular_priority, value) do
    regular_priority
    |> JobMonitor.update(value)
  end

  defp update_jobs(%{low_priority: low_priority}, @low_priority, value) do
    low_priority
    |> JobMonitor.update(value)
  end
end
