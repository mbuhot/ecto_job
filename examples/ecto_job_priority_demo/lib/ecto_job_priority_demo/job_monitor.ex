defmodule EctoJobPriorityDemo.JobMonitor do
  @moduledoc false
  use GenServer

  alias Ecto.Multi
  alias EctoJobPriorityDemo.JobQueue
  alias EctoJobPriorityDemo.Repo

  def start_link(jobs \\ %{count: 1, priority: 0, period: 1000}, server) do
    GenServer.start_link(__MODULE__, jobs, name: server)
  end

  def init(%{count: count, priority: priority, period: period}) do
    send(self(), {:produce_jobs, count, priority, period})
    {:ok, 0}
  end

  def update(server, value) do
    GenServer.cast(server, {:update, value})
  end

  def count(server) do
    GenServer.call(server, :count)
  end

  # Server

  def handle_cast({:update, value}, state) do
    {:noreply, state + value}
  end

  def handle_call(:count, _from, state) do
    {:reply, state, state}
  end

  def handle_info({:produce_jobs, count, priority, period}, state) do
    Multi.new()
    |> Multi.run(:create_jobs, fn _repo, _ ->
      jobs =
        Enum.map(1..count, fn _ ->
          %{
            state: "AVAILABLE",
            expires: nil,
            schedule: DateTime.utc_now(),
            attempt: 0,
            max_attempts: 5,
            params: %{priority: priority},
            notify: nil,
            priority: priority,
            retain_for: :timer.seconds(1),
            updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
            inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          }
        end)

      {:ok, jobs}
    end)
    |> Multi.run(:insert_jobs, fn _repo, %{create_jobs: jobs} ->
      result =
        JobQueue
        |> Repo.insert_all(jobs)

      {:ok, result}
    end)
    |> Repo.transaction()

    Process.send_after(self(), {:produce_jobs, count, priority, period}, period)

    {:noreply, state + count}
  end
end
