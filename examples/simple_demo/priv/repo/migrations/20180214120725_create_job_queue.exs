defmodule SimpleDemo.Repo.Migrations.CreateJobQueue do
  use Ecto.Migration

  def up do
    EctoJob.Migrations.Install.up()
    EctoJob.Migrations.CreateJobTable.up("jobs")
    EctoJob.Migrations.CreateJobTable.upgrade("jobs", "v0.2.0")
  end

  def down do
    EctoJob.Migrations.CreateJobTable.down("jobs")
    EctoJob.Migrations.Install.down()
  end
end
