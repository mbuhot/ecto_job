defmodule EctoJob.JobQueueTest do
  use ExUnit.Case, async: true
  alias EctoJob.Test.Repo
  require Ecto.Query, as: Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "JobQueue __using__ macro" do
    test "table_name is schema source" do
      assert EctoJob.Test.JobQueue.__schema__(:source) == "jobs"
    end

    test "Ecto schema fields are defined" do
      assert EctoJob.Test.JobQueue.__schema__(:fields) ==
        [
          :id,
          :state,
          :expires,
          :schedule,
          :attempt,
          :max_attempts,
          :module,
          :function,
          :arguments,
          :inserted_at,
          :updated_at
        ]
    end
  end

  describe "JobQueue.new" do
    test "contructs a Job from {Mod, Func, Args} tuple" do
      job = EctoJob.Test.JobQueue.new({IO, :puts, ["hello"]})
      assert %EctoJob.Test.JobQueue{module: "Elixir.IO", function: "puts"} = job
    end

    test "contructs a Job from a closure" do
      job = EctoJob.Test.JobQueue.new(&IO.inspect(&1))
      assert %EctoJob.Test.JobQueue{module: "Elixir.EctoJob.JobQueue", function: "perform"} = job
    end

    test "Accepts a :schedule option" do
      at = DateTime.from_naive!(~N[2055-05-22T12:34:44], "Etc/UTC")
      job = EctoJob.Test.JobQueue.new(&IO.inspect(&1), schedule: at)
      assert %{schedule: ^at, state: "SCHEDULED"} = job
    end

    test "Accepts a max_attempts option" do
      job = EctoJob.Test.JobQueue.new(&IO.inspect(&1), max_attempts: 123)
      assert job.max_attempts == 123
    end

    test "Serializes args to binary" do
      job = EctoJob.Test.JobQueue.new(&IO.inspect(&1, label: :foo))
      assert is_binary(job.arguments)
    end
  end

  describe "JobQueue.deserialize_job_args" do
    test "deserializes back to Elixir terms" do
      job = EctoJob.Test.JobQueue.new({IO, :inspect, [[label: :foo]]})
      assert {:ok, {IO, :inspect, [%Ecto.Multi{}, [label: :foo]]}} = EctoJob.JobQueue.deserialize_job_args(job)
    end

    test "Includes a Multi with delete job changeset" do
      job = EctoJob.Test.JobQueue.new({IO, :inspect, [[label: :foo]]}) |> Map.put(:id, 123)

      assert {:ok, {_, _, [multi = %Ecto.Multi{}, _]}} = EctoJob.JobQueue.deserialize_job_args(job)
      assert [{"delete_job_123", {:delete, cs = %Ecto.Changeset{}, []}}] = Ecto.Multi.to_list(multi)
      assert %{action: :delete, changes: %{attempt: 1}, data: ^job} = cs
    end
  end

  describe "JobQueue.enqueue" do
    test "Adds an operation to the Ecto.Multi" do
      multi =
        Ecto.Multi.new()
        |> EctoJob.Test.JobQueue.enqueue(:a_job, &IO.inspect(&1), max_attempts: 3)
        |> Ecto.Multi.to_list()

      assert [a_job: {:insert, %Ecto.Changeset{action: :insert, data: %EctoJob.Test.JobQueue{}}, []}] = multi
    end
  end

  describe "JobQueue.perform" do
    test "invokes the given function with argument" do
      assert %Ecto.Multi{} = EctoJob.JobQueue.perform(Ecto.Multi.new(), & &1)
    end
  end

  describe "JoqQueue.activate_scheduled_jobs" do
    test "Updates scheduled job to active" do
      at = DateTime.from_naive! ~N[2017-08-17T12:23:34Z], "Etc/UTC"
      now = DateTime.from_naive! ~N[2017-08-17T12:24:00Z], "Etc/UTC"
      %{id: id} = Repo.insert!(EctoJob.Test.JobQueue.new(&IO.inspect(&1), schedule: at))

      count = EctoJob.JobQueue.activate_scheduled_jobs(Repo, EctoJob.Test.JobQueue, now)

      assert count == 1
      assert Repo.get(EctoJob.Test.JobQueue, id).state == "AVAILABLE"
    end

    test "Does not activate job until scheduled time passed" do
      at = DateTime.from_naive! ~N[2017-08-17T12:23:34Z], "Etc/UTC"
      now = DateTime.from_naive! ~N[2017-08-17T12:20:00Z], "Etc/UTC"
      %{id: id} = Repo.insert!(EctoJob.Test.JobQueue.new(&IO.inspect(&1), schedule: at))

      count = EctoJob.JobQueue.activate_scheduled_jobs(Repo, EctoJob.Test.JobQueue, now)

      assert count == 0
      assert Repo.get(EctoJob.Test.JobQueue, id).state == "SCHEDULED"
    end

    test "Does not update a RESERVED job" do
      at = DateTime.from_naive! ~N[2017-08-17T12:23:34Z], "Etc/UTC"
      now = DateTime.from_naive! ~N[2017-08-17T12:24:00Z], "Etc/UTC"
      job =
        EctoJob.Test.JobQueue.new(&IO.inspect(&1), schedule: at)
        |> Map.put(:state, "RESERVED")
        |> Repo.insert!()

      count = EctoJob.JobQueue.activate_scheduled_jobs(Repo, EctoJob.Test.JobQueue, now)

      assert count == 0
      assert Repo.get(EctoJob.Test.JobQueue, job.id).state == "RESERVED"
    end
  end

  describe "JobQueue.activate_expired_jobs" do
    test "Updates an expired reserved job" do
      expiry = DateTime.from_naive! ~N[2017-08-17T12:23:34Z], "Etc/UTC"
      now = DateTime.from_naive! ~N[2017-08-17T12:24:00Z], "Etc/UTC"

      %{id: id} =
        EctoJob.Test.JobQueue.new(&IO.inspect(&1))
        |> Map.put(:state, "RESERVED")
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      count = EctoJob.JobQueue.activate_expired_jobs(Repo, EctoJob.Test.JobQueue, now)

      assert count == 1
      assert Repo.get(EctoJob.Test.JobQueue, id).state == "AVAILABLE"
    end

    test "Updates an expired in-progress job" do
      expiry = DateTime.from_naive! ~N[2017-08-17T12:23:34Z], "Etc/UTC"
      now = DateTime.from_naive! ~N[2017-08-17T12:24:00Z], "Etc/UTC"

      %{id: id} =
        EctoJob.Test.JobQueue.new(&IO.inspect(&1))
        |> Map.put(:state, "IN_PROGRESS")
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      count = EctoJob.JobQueue.activate_expired_jobs(Repo, EctoJob.Test.JobQueue, now)

      assert count == 1
      assert Repo.get(EctoJob.Test.JobQueue, id).state == "AVAILABLE"
    end

    test "Does not activate job until expiry time passed" do
      expiry = DateTime.from_naive! ~N[2017-08-17T12:23:34Z], "Etc/UTC"
      now = DateTime.from_naive! ~N[2017-08-17T12:20:00Z], "Etc/UTC"

      %{id: id} =
        EctoJob.Test.JobQueue.new(&IO.inspect(&1))
        |> Map.put(:state, "IN_PROGRESS")
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      count = EctoJob.JobQueue.activate_expired_jobs(Repo, EctoJob.Test.JobQueue, now)

      assert count == 0
      assert Repo.get(EctoJob.Test.JobQueue, id).state == "IN_PROGRESS"
    end

    test "Does not update a job after MAX_ATTEMPTS" do
      expiry = DateTime.from_naive! ~N[2017-08-17T12:23:34.0Z], "Etc/UTC"
      now = DateTime.from_naive! ~N[2017-08-17T12:24:00Z], "Etc/UTC"

      %{id: id} =
        EctoJob.Test.JobQueue.new(&IO.inspect(&1), max_attempts: 10)
        |> Map.put(:state, "IN_PROGRESS")
        |> Map.put(:attempt, 10)
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      count = EctoJob.JobQueue.activate_scheduled_jobs(Repo, EctoJob.Test.JobQueue, now)

      assert count == 0
      assert %{state: "IN_PROGRESS"} = job = Repo.get(EctoJob.Test.JobQueue, id)
      assert job.expires != nil
    end
  end

  describe "JobQueue.fail_expired_jobs_at_max_attempts" do
    test "FAILS expired in-progress jobs at max-attempts" do
      expiry = DateTime.from_naive! ~N[2017-08-17T12:23:34.0Z], "Etc/UTC"
      now = DateTime.from_naive! ~N[2017-08-17T12:24:00Z], "Etc/UTC"

      %{id: id} =
        EctoJob.Test.JobQueue.new(&IO.inspect(&1), max_attempts: 10)
        |> Map.put(:state, "IN_PROGRESS")
        |> Map.put(:attempt, 10)
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      count = EctoJob.JobQueue.fail_expired_jobs_at_max_attempts(Repo, EctoJob.Test.JobQueue, now)

      assert count == 1
      assert %{state: "FAILED"} = Repo.get(EctoJob.Test.JobQueue, id)
    end
  end

  describe "JobQueue.reserve_available_jobs" do
    test "RESERVES available jobs with 5 minute expiry" do
      for _ <- 1..5 do
        Repo.insert!(EctoJob.Test.JobQueue.new(&IO.inspect(&1)))
      end

      {3, [a, b, c]} = EctoJob.JobQueue.reserve_available_jobs(Repo, EctoJob.Test.JobQueue, 3, DateTime.utc_now)
      assert DateTime.compare(a.schedule, b.schedule) == :lt
      assert DateTime.compare(b.schedule, c.schedule) == :lt
      assert a.expires != nil
      assert a.state == "RESERVED"
      assert [d, _e] = Repo.all(Query.from EctoJob.Test.JobQueue, where: [state: "AVAILABLE"], order_by: [asc: :schedule])
      assert DateTime.compare(c.schedule, d.schedule) == :lt
    end
  end

  describe "JobQueue.update_job_in_progress" do
    test "Moves from RESERVED to IN_PROGRESS" do
      expiry = DateTime.from_naive! ~N[2017-08-17T12:23:34.0Z], "Etc/UTC"
      now = DateTime.from_naive! ~N[2017-08-17T12:20:00Z], "Etc/UTC"

      job =
        EctoJob.Test.JobQueue.new(&IO.inspect(&1))
        |> Map.put(:state, "RESERVED")
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      {:ok, new_job} = EctoJob.JobQueue.update_job_in_progress(Repo, job, now)

      assert new_job.state == "IN_PROGRESS"
      assert new_job.attempt == 1
      assert DateTime.compare(expiry, new_job.expires) == :lt
      assert Repo.all(Query.from EctoJob.Test.JobQueue, where: [state: "RESERVED"]) == []
    end

    test "Does not update if reservation expired" do
      expiry = DateTime.from_naive! ~N[2017-08-17T12:23:34.0Z], "Etc/UTC"
      now = DateTime.from_naive! ~N[2017-08-17T12:24:00Z], "Etc/UTC"

      job =
        EctoJob.Test.JobQueue.new(&IO.inspect(&1))
        |> Map.put(:state, "RESERVED")
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      {:error, :expired} = EctoJob.JobQueue.update_job_in_progress(Repo, job, now)
    end

    test "Does not update if attempt changed" do
      expiry = DateTime.from_naive! ~N[2017-08-17T12:23:34.0Z], "Etc/UTC"
      now = DateTime.from_naive! ~N[2017-08-17T12:20:00Z], "Etc/UTC"

      job =
        EctoJob.Test.JobQueue.new(&IO.inspect(&1))
        |> Map.put(:state, "RESERVED")
        |> Map.put(:expires, expiry)
        |> Map.put(:attempt, 3)
        |> Repo.insert!()

      {:error, :expired} = EctoJob.JobQueue.update_job_in_progress(Repo, %{job | attempt: 2}, now)
    end

    test "Does not update if state changed" do
      expiry = DateTime.from_naive! ~N[2017-08-17T12:23:34.0Z], "Etc/UTC"
      now = DateTime.from_naive! ~N[2017-08-17T12:20:00Z], "Etc/UTC"

      job =
        EctoJob.Test.JobQueue.new(&IO.inspect(&1))
        |> Map.put(:state, "IN_PROGRESS")
        |> Map.put(:expires, expiry)
        |> Map.put(:attempt, 3)
        |> Repo.insert!()

      {:error, :expired} = EctoJob.JobQueue.update_job_in_progress(Repo, %{job | state: "RESERVED"}, now)
    end
  end
end
