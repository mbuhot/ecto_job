defmodule EctoJob.WorkerTest do
  # credo:disable-for-this-file

  use ExUnit.Case, async: true
  alias EctoJob.Test.Repo
  alias EctoJob.Worker

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    %{
      config: %EctoJob.Config{
        repo: Repo,
        max_demand: 100,
        log: false,
        log_level: :info,
        poll_interval: 60_000,
        retrying_timeout: 30_000,
        reservation_timeout: 60_000,
        execution_timeout: 300_000,
        notifications_listen_timeout: 5_000}
      }
  end

  describe "Worker.start_link" do
    test "update job to the IN_PROGRESS state", %{config: config} do
      expiry = DateTime.from_naive!(~N[2017-08-17T12:23:34.0000000Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:20:00Z], "Etc/UTC")

      job =
        EctoJob.Test.JobQueue.new(%{})
        |> Map.put(:state, "RESERVED")
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      assert :ok == Worker.do_work(config, job, now)
    end

    test "return expired when the IN_PROGRESS job has expired", %{config: config} do
      expiry = DateTime.from_naive!(~N[2017-08-17T11:23:34.0000000Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:20:00Z], "Etc/UTC")

      job =
        EctoJob.Test.JobQueue.new(%{})
        |> Map.put(:state, "RESERVED")
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      assert {:error, :expired} == Worker.do_work(config, job, now)
    end

    test "changes the state to RETRYING when the multi transaction fails", %{config: config} do
      expiry = DateTime.from_naive!(~N[2017-08-17T12:23:34.0000000Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:20:00Z], "Etc/UTC")

      job =
        EctoJob.Test.TransactionFailJobQueue.new(%{})
        |> Map.put(:state, "RESERVED")
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      assert {:ok, _} = Worker.do_work(config, job, now)
      assert Repo.get(EctoJob.Test.JobQueue, job.id).state == "RETRYING"
    end

    test "changes the state to RETRYING when perform raises an exception", %{config: config} do
      expiry = DateTime.from_naive!(~N[2017-08-17T12:23:34.0000000Z], "Etc/UTC")
      now = DateTime.from_naive!(~N[2017-08-17T12:20:00Z], "Etc/UTC")

      job =
        EctoJob.Test.ExceptionJobQueue.new(%{})
        |> Map.put(:state, "RESERVED")
        |> Map.put(:expires, expiry)
        |> Repo.insert!()

      try do
        Worker.do_work(config, job, now)
      rescue
        _ -> assert Repo.get(EctoJob.Test.JobQueue, job.id).state == "RETRYING"
      else
        _ -> assert false
      end

    end
  end
end
