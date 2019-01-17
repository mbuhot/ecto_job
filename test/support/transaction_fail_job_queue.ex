defmodule EctoJob.Test.TransactionFailJobQueue do
  # credo:disable-for-this-file

  use EctoJob.JobQueue, table_name: "jobs"

  def perform(multi, _params) do
    multi
    |> Ecto.Multi.run(:send, fn _,_ -> {:error, "Error"} end)
    |> EctoJob.Test.Repo.transaction()
  end
end
