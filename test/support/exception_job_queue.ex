defmodule EctoJob.Test.ExceptionJobQueue do
  # credo:disable-for-this-file

  use EctoJob.JobQueue, table_name: "jobs"

  def perform(_multi, _params) do
    raise "Exception"
  end
end
