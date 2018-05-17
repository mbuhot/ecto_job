defmodule EctoJob.JobQueueTest do
  # credo:disable-for-this-file

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
                 :params,
                 :notify,
                 :inserted_at,
                 :updated_at
               ]
    end
  end

  describe "JobQueue.new" do
    test "contructs a Job from params" do
      job = EctoJob.Test.JobQueue.new(%{a: 1, b: "hello", c: [1, 2, 3]})
      assert %EctoJob.Test.JobQueue{params: %{a: 1, b: "hello", c: [1, 2, 3]}} = job
    end

    test "Accepts a :schedule option" do
      at = DateTime.from_naive!(~N[2055-05-22T12:34:44], "Etc/UTC")
      job = EctoJob.Test.JobQueue.new(%{}, schedule: at)
      assert %{schedule: ^at, state: "SCHEDULED"} = job
    end

    test "Accepts a max_attempts option" do
      job = EctoJob.Test.JobQueue.new(%{}, max_attempts: 123)
      assert job.max_attempts == 123
    end
  end

  describe "JobQueue.enqueue" do
    test "Adds an operation to the Ecto.Multi" do
      multi =
        Ecto.Multi.new()
        |> EctoJob.Test.JobQueue.enqueue(:a_job, %{}, max_attempts: 3)
        |> Ecto.Multi.to_list()

      assert [
               a_job:
                 {:insert, %Ecto.Changeset{action: :insert, data: %EctoJob.Test.JobQueue{}}, []}
             ] = multi
    end
  end

  describe "JoqQueue.activate_scheduled_jobs" do
    test "Updates scheduled job to AVAILABLE" do
      at = DateTime.from_naive!(~N[2017-08-17T12:23:34Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:24:00Z], "Etc/UTC")
      %{id: id} = Repo.insert!(EctoJob.Test.JobQueue.new(%{}, schedule: at))

      count = EctoJob.JobQueue.activate_scheduled_jobs(Repo, EctoJob.Test.JobQueue, now)

      assert count == 1
      assert Repo.get(EctoJob.Test.JobQueue, id).state == "AVAILABLE"
    end

    test "Does not activate job until scheduled time passed" do
      at = DateTime.from_naive!(~N[2017-08-17T12:23:34Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:20:00Z], "Etc/UTC")
      %{id: id} = Repo.insert!(EctoJob.Test.JobQueue.new(%{}, schedule: at))

      count = EctoJob.JobQueue.activate_scheduled_jobs(Repo, EctoJob.Test.JobQueue, now)

      assert count == 0
      assert Repo.get(EctoJob.Test.JobQueue, id).state == "SCHEDULED"
    end

    test "Does not activate a RESERVED job" do
      at = DateTime.from_naive!(~N[2017-08-17T12:23:34Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:24:00Z], "Etc/UTC")

      job =
        EctoJob.Test.JobQueue.new(%{}, schedule: at)
        |> Map.put(:state, "RESERVED")
        |> Repo.insert!()

      count = EctoJob.JobQueue.activate_scheduled_jobs(Repo, EctoJob.Test.JobQueue, now)

      assert count == 0
      assert Repo.get(EctoJob.Test.JobQueue, job.id).state == "RESERVED"
    end
  end

  describe "JobQueue.activate_expired_jobs" do
    test "Updates an expired reserved job to AVAILABLE" do
      expiry = DateTime.from_naive!(~N[2017-08-17T12:23:34Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:24:00Z], "Etc/UTC")

      %{id: id} =
        EctoJob.Test.JobQueue.new(%{})
        |> Map.put(:state, "RESERVED")
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      count = EctoJob.JobQueue.activate_expired_jobs(Repo, EctoJob.Test.JobQueue, now)

      assert count == 1
      assert Repo.get(EctoJob.Test.JobQueue, id).state == "AVAILABLE"
    end

    test "Updates an expired IN_PROGRESS job to AVAILABLE" do
      expiry = DateTime.from_naive!(~N[2017-08-17T12:23:34Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:24:00Z], "Etc/UTC")

      %{id: id} =
        EctoJob.Test.JobQueue.new(%{})
        |> Map.put(:state, "IN_PROGRESS")
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      count = EctoJob.JobQueue.activate_expired_jobs(Repo, EctoJob.Test.JobQueue, now)

      assert count == 1
      assert Repo.get(EctoJob.Test.JobQueue, id).state == "AVAILABLE"
    end

    test "Does not activate job until expiry time passed" do
      expiry = DateTime.from_naive!(~N[2017-08-17T12:23:34Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:20:00Z], "Etc/UTC")

      %{id: id} =
        EctoJob.Test.JobQueue.new(%{})
        |> Map.put(:state, "IN_PROGRESS")
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      count = EctoJob.JobQueue.activate_expired_jobs(Repo, EctoJob.Test.JobQueue, now)

      assert count == 0
      assert Repo.get(EctoJob.Test.JobQueue, id).state == "IN_PROGRESS"
    end

    test "Does not update a job after max_attempts" do
      expiry = DateTime.from_naive!(~N[2017-08-17T12:23:34.0Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:24:00Z], "Etc/UTC")

      %{id: id} =
        EctoJob.Test.JobQueue.new(%{}, max_attempts: 10)
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
    test "FAILS expired IN_PROGRESS jobs at max_attempts" do
      expiry = DateTime.from_naive!(~N[2017-08-17T12:23:34.0Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:24:00Z], "Etc/UTC")

      %{id: id} =
        EctoJob.Test.JobQueue.new(%{}, max_attempts: 10)
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
    test "RESERVES available jobs with configurable expiry" do
      for _ <- 1..6 do
        Repo.insert!(EctoJob.Test.JobQueue.new(%{}))
      end

      reserve_jobs = fn demand, expiry ->
        EctoJob.JobQueue.reserve_available_jobs(
          Repo,
          EctoJob.Test.JobQueue,
          demand,
          DateTime.utc_now(),
          expiry
        )
      end

      {3, [a, b, c]} = reserve_jobs.(3, 300)
      {1, [d]} = reserve_jobs.(1, 120)

      assert DateTime.compare(a.schedule, b.schedule) == :lt
      assert DateTime.compare(b.schedule, c.schedule) == :lt
      assert a.expires != nil
      assert a.state == "RESERVED"

      assert DateTime.compare(c.expires, d.expires) == :gt

      assert [e, _f] =
               Repo.all(
                 Query.from(
                   EctoJob.Test.JobQueue,
                   where: [state: "AVAILABLE"],
                   order_by: [asc: :schedule]
                 )
               )

      assert DateTime.compare(c.schedule, e.schedule) == :lt
    end
  end

  describe "JobQueue.update_job_in_progress" do
    test "Moves from RESERVED to IN_PROGRESS" do
      expiry = DateTime.from_naive!(~N[2017-08-17T12:23:34.0Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:20:00Z], "Etc/UTC")

      job =
        EctoJob.Test.JobQueue.new(%{})
        |> Map.put(:state, "RESERVED")
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      {:ok, new_job} = EctoJob.JobQueue.update_job_in_progress(Repo, job, now)

      assert new_job.state == "IN_PROGRESS"
      assert new_job.attempt == 1
      assert DateTime.compare(expiry, new_job.expires) == :lt
      assert Repo.all(Query.from(EctoJob.Test.JobQueue, where: [state: "RESERVED"])) == []
    end

    test "Uses product of configurable base expiry and next attempt to set expiry" do
      expiry = DateTime.from_naive!(~N[2017-08-17T12:29:34.0Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:20:00Z], "Etc/UTC")

      attempt = 2
      base_expiry = 600

      job =
        EctoJob.Test.JobQueue.new(%{})
        |> Map.put(:state, "RESERVED")
        |> Map.put(:expires, expiry)
        |> Map.put(:attempt, attempt)
        |> Repo.insert!()

      {:ok, new_job} = EctoJob.JobQueue.update_job_in_progress(Repo, job, now, base_expiry)

      assert DateTime.diff(new_job.expires, now, :seconds) == base_expiry * (attempt + 1)
    end

    test "Does not update if reservation expired" do
      expiry = DateTime.from_naive!(~N[2017-08-17T12:23:34.0Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:24:00Z], "Etc/UTC")

      job =
        EctoJob.Test.JobQueue.new(%{})
        |> Map.put(:state, "RESERVED")
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      {:error, :expired} = EctoJob.JobQueue.update_job_in_progress(Repo, job, now)
    end

    test "Does not update if attempt changed" do
      expiry = DateTime.from_naive!(~N[2017-08-17T12:23:34.0Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:20:00Z], "Etc/UTC")

      job =
        EctoJob.Test.JobQueue.new(%{})
        |> Map.put(:state, "RESERVED")
        |> Map.put(:expires, expiry)
        |> Map.put(:attempt, 3)
        |> Repo.insert!()

      {:error, :expired} = EctoJob.JobQueue.update_job_in_progress(Repo, %{job | attempt: 2}, now)
    end

    test "Does not update if state changed" do
      expiry = DateTime.from_naive!(~N[2017-08-17T12:23:34.0Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:20:00Z], "Etc/UTC")

      job =
        EctoJob.Test.JobQueue.new(%{})
        |> Map.put(:state, "IN_PROGRESS")
        |> Map.put(:expires, expiry)
        |> Map.put(:attempt, 3)
        |> Repo.insert!()

      {:error, :expired} =
        EctoJob.JobQueue.update_job_in_progress(Repo, %{job | state: "RESERVED"}, now)
    end
  end
end
