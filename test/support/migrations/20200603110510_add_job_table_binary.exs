defmodule EctoJob.Test.Repo.Migrations.AddJobTableBinary do
  use Ecto.Migration
  alias EctoJob.Migrations.{CreateJobTable, Install}

  @ecto_job_version 3

  def up do
    CreateJobTable.up("jobs_binary",
      version: @ecto_job_version,
      params_type: :binary
    )
  end

  def down do
    CreateJobTable.down("jobs_binary")
  end
end
