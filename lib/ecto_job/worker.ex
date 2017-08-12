defmodule EctoJob.Worker do
  alias EctoJob.JobQueue

  def start_link(repo, job) do
    now = DateTime.utc_now()
    with {:ok, job} <- JobQueue.update_job_in_progress(repo, job, now),
         {mod, func, args} <- JobQueue.deserialize_job_args(job) do
      Task.start_link(mod, func, args)
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
