defmodule EctoJob.Test.JobQueue do
  use EctoJob.JobQueue, table_name: "jobs"

  def perform(multi, params) do
    IO.inspect({multi, params})
  end

end
