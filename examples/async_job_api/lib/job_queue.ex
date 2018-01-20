defmodule AsyncJobApi.JobQueue do
  use EctoJob.JobQueue, table_name: "jobs"

  alias AsyncJobApi.Repo

  @impl EctoJob.JobQueue
  def perform(multi, _job) do
    Process.sleep(10000)
    multi
    |> Repo.transaction()
  end
end