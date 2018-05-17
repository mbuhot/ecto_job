defmodule EctoJob.Worker do
  @moduledoc """
  Worker module responsible for executing a single Job
  """
  alias EctoJob.{Config, JobQueue}
  require Logger

  @type repo :: module

  @doc """
  Equivalent to `start_link(config, job, DateTime.utc_now())`
  """
  @spec start_link(Config.t, EctoJob.JobQueue.job()) :: {:ok, pid}
  def start_link(config, job), do: start_link(config, job, DateTime.utc_now())

  @doc """
  Start a worker process given a repo module and a job struct
  This may fail if the job reservation has expired, in which case the job will be
  reactivated by the producer.
  """
  @spec start_link(Config.t, EctoJob.JobQueue.job(), DateTime.t()) :: {:ok, pid}
  def start_link(config = %Config{repo: repo, base_expiry_seconds: base_expiry}, job = %queue{}, now) do
    Task.start_link(fn ->
      with {:ok, job} <- JobQueue.update_job_in_progress(repo, job, now, base_expiry) do
        queue.perform(JobQueue.initial_multi(job), job.params)
        log_duration(config, job, now)
        notify_completed(repo, job)
      end
    end)
  end

  @spec log_duration(Config.t, EctoJob.JobQueue.job(), DateTime.t()) :: :ok
  defp log_duration(%Config{log: true, log_level: log_level}, _job = %queue{id: id}, start = %DateTime{}) do
    duration = DateTime.diff(DateTime.utc_now(), start, :microseconds)
    Logger.log(log_level, fn -> "#{queue}[#{id}] done: #{duration} µs" end)
  end
  defp log_duration(_config, _job, _start), do: :ok

  @spec notify_completed(repo, EctoJob.JobQueue.job()) :: :ok
  defp notify_completed(_repo, _job = %{notify: nil}), do: :ok

  defp notify_completed(repo, _job = %queue{notify: payload}) do
    topic = queue.__schema__(:source) <> ".completed"
    repo.query("SELECT pg_notify($1, $2)", [topic, payload])
    :ok
  end
end
