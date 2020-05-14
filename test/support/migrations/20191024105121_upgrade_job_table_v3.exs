defmodule EctoJob.Test.Repo.Migrations.UpgradeJobTableV3 do
  use Ecto.Migration

  @ecto_job_version 3

  def up do
    EctoJob.Migrations.UpdateJobTable.up(@ecto_job_version, "jobs")
  end

  def down do
    EctoJob.Migrations.UpdateJobTable.down(@ecto_job_version, "jobs")
  end
end
