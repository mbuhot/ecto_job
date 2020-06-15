defmodule EctoJob.Migrations do
  @moduledoc false

  defmodule Helpers do
    @moduledoc false

    def qualify(name, nil), do: name
    def qualify(name, prefix), do: "#{prefix}.#{name}"
  end

  defmodule Install do
    @moduledoc """
    Defines migrations for installing shared functions
    """

    import Ecto.Migration

    @doc """
    Creates the `fn_notify_inserted` trigger function.
    This function will be called from triggers attached to job queue tables.

    ## Options

    * `:prefix` - the prefix (aka Postgresql schema) to create the functions in.
    """
    def up(opts \\ []) do
      prefix = Keyword.get(opts, :prefix)

      execute("""
      CREATE FUNCTION #{Helpers.qualify("fn_notify_inserted", prefix)}()
        RETURNS trigger AS $$
      DECLARE
      BEGIN
        PERFORM pg_notify(TG_TABLE_NAME, '');
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
      """)
    end

    @doc """
    Drops the `fn_notify_inserted` trigger function

    ## Options

    * `:prefix` - the prefix (aka Postgresql schema) containing the function to remove.
    """
    def down(opts \\ []) do
      prefix = Keyword.get(opts, :prefix)
      execute("DROP FUNCTION #{Helpers.qualify("fn_notify_inserted", prefix)}()")
    end
  end

  defmodule CreateJobTable do
    @moduledoc """
    Defines a migration to create a table to be used as a job queue.
    This migration can be run multiple times with different values to create multiple queues.
    """

    import Ecto.Migration

    @doc """
    Adds a job queue table with the given name, and attaches an insert trigger.

    ## Options

    * `:prefix` - the prefix (aka Postgresql schema) to create the table in.
    * `:version` - the major version of the EctoJob library used to generate the table
    * `:timestamps` - A keyword list of options passed to the `Ecto.Migration.timestamps/1` function.
    """
    def up(name, opts \\ []) do
      opts = [{:primary_key, false} | opts]
      prefix = Keyword.get(opts, :prefix)
      timestamp_opts = Keyword.get(opts, :timestamps, [])
      version = Keyword.get(opts, :version, 4)

      create table(name, opts) do
        add(:id, :bigserial, primary_key: true)
        add(:state, :string, null: false, default: "AVAILABLE")
        add(:expires, :utc_datetime_usec)

        add(:schedule, :utc_datetime_usec,
          null: false,
          default: fragment("timezone('UTC', now())")
        )

        add(:attempt, :integer, null: false, default: 0)
        add(:max_attempts, :integer, null: false, default: 5)
        add(:params, :map, null: false)
        add(:notify, :string)

        if version >= 3 do
          add(:priority, :integer, null: false, default: 0)
        end

        if version >= 4 do
          add(:idempotency_key, :string)
          add(:retain_for, :bigint, null: false, default: 0)
        end

        timestamps(timestamp_opts)
      end

      cond do
        version == 2 ->
          create(index(name, [:schedule, :id]))

        version == 3 ->
          create(index(name, [:priority, :schedule, :id]))

        version >= 4 ->
          create(index(name, [:priority, :schedule, :id]))
          create(unique_index(name, :idempotency_key))

        true ->
          nil
      end

      execute("""
      CREATE TRIGGER tr_notify_inserted_#{name}
      AFTER INSERT ON #{Helpers.qualify(name, prefix)}
      FOR EACH ROW
      EXECUTE PROCEDURE #{Helpers.qualify("fn_notify_inserted", prefix)}();
      """)
    end

    @doc """
    Drops the job queue table with the given name, and associated trigger

    ## Options

    * `:prefix` - the prefix (aka Postgresql schema) containing the table to remove.
    """
    def down(name, opts \\ []) do
      prefix = Keyword.get(opts, :prefix)
      execute("DROP TRIGGER tr_notify_inserted_#{name} ON #{Helpers.qualify(name, prefix)}")
      execute("DROP TABLE #{Helpers.qualify(name, prefix)}")
    end
  end

  defmodule UpdateJobTable do
    @moduledoc """
    Defines an update migration to an especific version of Ecto Job.
    This migration can be run multiple times with different values to update multiple queues.
    """

    import Ecto.Migration

    @doc """
    Upgrade the job queue table with the given ecto job version and name.
    """
    def up(3, name) do
      alter table(name) do
        add(:priority, :integer, null: false, default: 0)
      end

      create(index(name, [:priority, :schedule, :id]))
    end

    def up(4, name) do
      alter table(name) do
        add(:idempotency_key, :string)
        add(:retain_for, :bigint, null: false, default: 0)
      end

      create(unique_index(name, :idempotency_key))
    end

    @doc """
    Rollback updates from job queue table with the given ecto job version and name.
    """
    def down(3, name) do
      drop(index(name, [:priority, :schedule, :id]))

      alter table(name) do
        remove(:priority)
      end
    end

    def down(4, name) do
      drop(unique_index(name, :idempotency_key))

      alter table(name) do
        remove(:idempotency_key)
        remove(:retain_for)
      end
    end
  end
end
