defmodule EctoJob.Test.Repo.Migrations.AddJobTableBinary do
  use Ecto.Migration
  alias EctoJob.Migrations.{CreateJobTable, Install}

  @ecto_job_version 3

  def up do
    execute("CREATE SCHEMA \"params_binary\";")
    Install.up(prefix: "params_binary")

    CreateJobTable.up("jobs",
      version: @ecto_job_version,
      prefix: "params_binary",
      params_type: :binary
    )
  end

  def down do
    CreateJobTable.down("jobs", prefix: "parasm_binary")
    Intall.down(prefix: "params_binary")
    execute("DROP SCHEMA \"params_binary\";")
  end
end
