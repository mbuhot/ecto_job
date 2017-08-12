defmodule EctoJob.Migrations do
  defmodule Install do
    import Ecto.Migration

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

    def down do
      execute "DROP FUNCTION fn_notify_inserted()"
    end
  end

  defmodule CreateJobTable do
    import Ecto.Migration

    def up(name) do
      create table(name) do
        add :state, :string, null: false, default: "AVAILABLE"
        add :expires, :utc_datetime
        add :schedule, :utc_datetime, null: false, default: fragment("timezone('UTC', now())")
        add :attempt, :integer, null: false, default: 0
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

    def down(name) do
      execute "DROP FUNCTION tr_notify_inserted_#{name}()"
      execute "DROP TABLE #{name}"
    end
  end
end
