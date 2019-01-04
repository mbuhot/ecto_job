defmodule EctoJob.Test.JobQueue do
  # credo:disable-for-this-file

  use EctoJob.JobQueue, table_name: "jobs"

  def perform(multi, params) do
    IO.inspect({multi, params})

    EctoJob.Test.Repo.transaction(multi)
  end
end
