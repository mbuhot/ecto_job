defmodule EctoJob.Test.JobQueue do
  @moduledoc false
  use EctoJob.JobQueue, table_name: "jobs"

  alias EctoJob.Test.Repo

  def perform(multi, _params) do
    Repo.transaction(multi)
  end
end
