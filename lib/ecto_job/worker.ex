defmodule EctoJob.Worker do
  @moduledoc """
  Worker module responsible for executing a single Job
  """
  alias EctoJob.JobQueue

  @type repo :: module

  @doc """
  Start a worker process given a repo module and a job struct
  This may fail if the job reservation has expired, in which case the job will be
  reactivated by the producer.
  """
  @spec start_link(repo, EctoJob.JobQueue.job) :: {:ok, pid} | {:error, term}
  def start_link(repo, job) do
    now = DateTime.utc_now()
    with {:ok, job} <- JobQueue.update_job_in_progress(repo, job, now),
         {:ok, {mod, func, args}} <- JobQueue.deserialize_job_args(job) do
      Task.start_link(mod, func, args)
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
