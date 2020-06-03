defmodule EctoJob.Test.Repo.Migrations.UpgradeJobTableV4 do
  use Ecto.Migration

  alias EctoJob.Migrations.UpdateJobTable

  @ecto_job_version 4

  def up do
    UpdateJobTable.up(@ecto_job_version, "jobs")
  end

  def down do
    UpdateJobTable.down(@ecto_job_version, "jobs")
  end
end
