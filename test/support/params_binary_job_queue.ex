defmodule EctoJob.Test.ParamsBinaryJobQueue do
  @moduledoc false
  use EctoJob.JobQueue, table_name: "jobs", schema_prefix: "params_binary", params_type: :binary

  def perform(multi, _params) do
    EctoJob.Test.Repo.transaction(multi)
  end
end
