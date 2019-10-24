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
  @spec start_link(Config.t(), EctoJob.JobQueue.job()) :: {:ok, pid}
  def start_link(config, job), do: start_link(config, job, DateTime.utc_now())

  @doc """
  Start a worker process given a repo module and a job struct
  This may fail if the job reservation has expired, in which case the job will be
  reactivated by the producer.
  """
  @spec start_link(Config.t(), EctoJob.JobQueue.job(), DateTime.t()) :: {:ok, pid}
  def start_link(config, job, now) do
    Task.start_link(fn -> do_work(config, job, now) end)
  end

  @doc false
  @spec do_work(Config.t(), EctoJob.JobQueue.job(), DateTime.t()) :: :ok | {:error, any()}
  def do_work(config = %Config{repo: repo, execution_timeout: exec_timeout}, job, now) do
    with {:ok, in_progress_job} <- JobQueue.update_job_in_progress(repo, job, now, exec_timeout),
         :ok <- run_job(config, in_progress_job) do
      log_duration(config, in_progress_job, now)
      notify_completed(repo, in_progress_job)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec run_job(Config.t(), EctoJob.JobQueue.job()) :: :ok
  defp run_job(%Config{repo: repo, retry_timeout: timeout}, job = %queue{}) do
    job_failed = fn ->
      _ = JobQueue.job_failed(repo, job, DateTime.utc_now(), timeout)
      :ok
    end

    try do
      case queue.perform(JobQueue.initial_multi(job), job.params) do
        {:ok, _value} -> :ok
        {:error, _value} -> job_failed.()
        {:error, _failed_operation, _failed_value, _changes_so_far} -> job_failed.()
      end
    rescue
      e ->
        # An exception occurred, make an attempt to put the job into the RETRY state
        # before propagating the exception
        stacktrace = System.stacktrace()
        job_failed.()
        reraise(e, stacktrace)
    end
  end

  @spec log_duration(Config.t(), EctoJob.JobQueue.job(), DateTime.t()) :: :ok
  defp log_duration(
         %Config{log: true, log_level: log_level},
         _job = %queue{id: id},
         start = %DateTime{}
       ) do
    duration = DateTime.diff(DateTime.utc_now(), start, :microsecond)
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
