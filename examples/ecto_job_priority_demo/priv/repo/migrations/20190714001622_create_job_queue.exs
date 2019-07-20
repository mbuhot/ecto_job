defmodule EctoJobPriorityDemo.Repo.Migrations.CreateJobQueue do
  @moduledoc false
  use Ecto.Migration

  def up do
    EctoJob.Migrations.Install.up()
    EctoJob.Migrations.CreateJobTable.up("jobs")
  end

  def down do
    EctoJob.Migrations.CreateJobTable.down("jobs")
    EctoJob.Migrations.Install.down()
  end
end
