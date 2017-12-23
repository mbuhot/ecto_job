defmodule EctoJob.Worker do
  @moduledoc """
  Worker module responsible for executing a single Job
  """
  alias EctoJob.JobQueue
  require Logger

  @type repo :: module

  @doc """
  Equivalent to `start_link(repo, job, DateTime.utc_now())`
  """
  @spec start_link(repo, EctoJob.JobQueue.job) :: {:ok, pid}
  def start_link(repo, job), do: start_link(repo, job, DateTime.utc_now())

  @doc """
  Start a worker process given a repo module and a job struct
  This may fail if the job reservation has expired, in which case the job will be
  reactivated by the producer.
  """
  @spec start_link(repo, EctoJob.JobQueue.job, DateTime.t) :: {:ok, pid}
  def start_link(repo, job = %queue{}, now) do
    Task.start_link(fn ->
      with {:ok, job} <- JobQueue.update_job_in_progress(repo, job, now) do
        queue.perform(JobQueue.initial_multi(job), job.params)
        log_duration(job, now)
        notify_completed(repo, job)
      end
    end)
  end

  @spec log_duration(EctoJob.JobQueue.job, DateTime.t) :: :ok
  defp log_duration(_job = %queue{id: id}, start = %DateTime{}) do
    duration = DateTime.diff(DateTime.utc_now(), start, :microseconds)
    Logger.info("#{queue}[#{id}] done: #{duration} µs")
  end

  @spec notify_completed(repo, EctoJob.JobQueue.job) :: :ok
  defp notify_completed(_repo, _job = %{notify: nil}), do: :ok
  defp notify_completed(repo, _job = %queue{notify: payload}) do
    topic = queue.__schema__(:source) <> ".completed"
    repo.query("SELECT pg_notify($1, $2)", [topic, payload])
    :ok
  end
end
