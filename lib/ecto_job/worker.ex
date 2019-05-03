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
  def start_link(config, job, now) do
    Task.start_link(fn -> do_work(config, job, now) end)
  end

  @spec do_work(Config.t, EctoJob.JobQueue.job(), DateTime.t()) ::
          :ok | {:ok, EctoJob.JobQueue.job()} | {:error, any()}
  def do_work(config = %Config{repo: repo,
                               execution_timeout: exec_timeout,
                               retrying_timeout: retrying_timeout},
              job,
              now) do
    with {:ok, in_progress_job} <- JobQueue.update_job_in_progress(repo, job, now, exec_timeout),
                       response <- run_queue(config, in_progress_job),
                           true <- valid?(response) do
      log_duration(config, in_progress_job, now)
      notify_completed(repo, in_progress_job)
    else
      false -> JobQueue.update_job_to_retrying(repo, job, DateTime.utc_now(), retrying_timeout)
      error -> error
    end
  end

  @spec run_queue(Config.t, EctoJob.JobQueue.job()) :: any()
  defp run_queue(%Config{repo: repo, retrying_timeout: timeout}, job = %queue{}) do
    try do
      queue.perform(JobQueue.initial_multi(job), job.params)
    rescue
      e ->
        stacktrace = System.stacktrace()

        _ = JobQueue.update_job_to_retrying(repo, job, DateTime.utc_now(), timeout)

        reraise(e, stacktrace)
    end
  end

  @spec valid?(any()) :: boolean()
  defp valid?(:error), do: false

  defp valid?(response) when is_tuple(response), do: :error != elem(response, 0)

  defp valid?(_), do: true

  @spec log_duration(Config.t, EctoJob.JobQueue.job(), DateTime.t()) :: :ok
  defp log_duration(%Config{log: true, log_level: log_level}, _job = %queue{id: id}, start = %DateTime{}) do
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
