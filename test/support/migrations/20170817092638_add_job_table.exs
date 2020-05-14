defmodule EctoJob.Test.Repo.Migrations.AddJobTable do
  use Ecto.Migration
  alias EctoJob.Migrations.{CreateJobTable, Install}

  @ecto_job_version 2

  def up do
    Install.up()
    CreateJobTable.up("jobs", version: @ecto_job_version)
  end

  def down do
    CreateJobTable.down("jobs")
    Intall.down()
  end
end
