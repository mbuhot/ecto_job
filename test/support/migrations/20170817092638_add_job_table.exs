defmodule EctoJob.Test.Repo.Migrations.AddJobTable do
  use Ecto.Migration

  def up do
    EctoJob.Migrations.Install.up()
    EctoJob.Migrations.CreateJobTable.up("jobs")
  end

  def down do
    EctoJob.Migrations.CreateJobTable.down("jobs")
    EctoJob.Migrations.Intall.down()
  end
end
