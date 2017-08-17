defmodule EctoJob.Migrations do
  @moduledoc false

  defmodule Install do
    @moduledoc """
    Defines migrations for installing shared functions
    """

    import Ecto.Migration

    @doc """
    Creates the `fn_notify_inserted` trigger function.
    This function will be called from triggers attached to job queue tables.
    """
    def up do
      execute """
        CREATE FUNCTION fn_notify_inserted()
          RETURNS trigger AS $$
        DECLARE
        BEGIN
          PERFORM pg_notify(TG_TABLE_NAME, '');
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
        """
    end

    @doc """
    Drops the `fn_notify_inserted` trigger function
    """
    def down do
      execute "DROP FUNCTION fn_notify_inserted()"
    end
  end

  defmodule CreateJobTable do
    @moduledoc """
    Adds a job queue table with the given name, and attaches an insert trigger.
    """
    import Ecto.Migration

    def up(name) do
      _ = create table(name) do
        add :state, :string, null: false, default: "AVAILABLE"
        add :expires, :utc_datetime
        add :schedule, :utc_datetime, null: false, default: fragment("timezone('UTC', now())")
        add :attempt, :integer, null: false, default: 0
        add :max_attempts, :integer, null: false, default: 5
        add :module, :string, null: false
        add :function, :string, null: false
        add :arguments, :binary, null: false
        timestamps()
      end

      execute """
        CREATE TRIGGER tr_notify_inserted_#{name}
        AFTER INSERT ON #{name}
        FOR EACH ROW
        EXECUTE PROCEDURE fn_notify_inserted();
        """
    end

    @doc """
    Drops the job queue table with the given name, and associated trigger
    """
    def down(name) do
      execute "DROP FUNCTION tr_notify_inserted_#{name}()"
      execute "DROP TABLE #{name}"
    end
  end
end
