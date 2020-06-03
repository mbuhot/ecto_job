defmodule EctoJob.Test.Repo.Migrations.UpgradeJobTableV3 do
  use Ecto.Migration

  alias EctoJob.Migrations.UpdateJobTable

  @ecto_job_version 3

  def up do
    UpdateJobTable.up(@ecto_job_version, "jobs")
  end

  def down do
    UpdateJobTable.down(@ecto_job_version, "jobs")
  end
end
