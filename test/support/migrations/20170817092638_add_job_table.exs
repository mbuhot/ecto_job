defmodule EctoJob.Test.Repo.Migrations.AddJobTable do
  use Ecto.Migration
  alias EctoJob.Migrations.{CreateJobTable, Install}

  def up do
    Install.up()
    CreateJobTable.up("jobs")
  end

  def down do
    CreateJobTable.down("jobs")
    Intall.down()
  end
end
