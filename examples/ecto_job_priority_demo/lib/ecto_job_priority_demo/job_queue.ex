defmodule EctoJobPriorityDemo.JobQueue do
  use EctoJob.JobQueue, table_name: "jobs"

  def perform(multi, %{"priority" => priority}) do
    multi
    |> Ecto.Multi.run(:resolve, fn _repo, _changes ->
      make_work_heavy(priority)
      {:ok, EctoJobPriorityDemo.resolve(priority)}
    end)
    |> EctoJobPriorityDemo.Repo.transaction()
  end

  @doc """
  This method make high priority jobs heavy

  high_priority    = 100 - (0 * 50) = 100
  regular_priority = 100 - (1 * 50) = 50
  low_priority     = 100 - (2 * 50) = 0
  """
  defp make_work_heavy(priority) do
    (100 - priority * 50)
    |> Process.sleep()
  end
end
