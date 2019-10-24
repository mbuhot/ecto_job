defmodule EctoJob.Test.JobQueue do
  @moduledoc false
  use EctoJob.JobQueue, table_name: "jobs"

  def perform(multi, _params) do
    EctoJob.Test.Repo.transaction(multi)
  end
end
