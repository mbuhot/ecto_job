defmodule EctoJobDemo.JobQueue do
  use EctoJob.JobQueue, table_name: "jobs"

  def perform(multi, %{"hello" => name}) do
    EctoJobDemo.hello(multi, name)
  end
end
