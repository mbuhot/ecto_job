defmodule EctoJob.ProducerTest do
  use ExUnit.Case, async: true
  alias EctoJob.Producer
  alias EctoJob.Test.{JobQueue, Repo}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    %{
      state: %Producer.State{
        repo: Repo,
        schema: JobQueue,
        notifier: nil,
        demand: 0,
        clock: fn -> DateTime.from_naive!(~N[2017-08-17T12:24:00Z], "Etc/UTC") end,
        poll_interval: 60_000,
        reservation_timeout: 60_000,
        execution_timeout: 300_000,
        always_dispatch_jobs_on_poll: false
      }
    }
  end

  describe "handle_info :poll" do
    test "When demand=0", %{state: state} do
      Repo.insert!(JobQueue.new(%{}))
      assert {:noreply, [], ^state} = Producer.handle_info(:poll, state)
    end

    test "When scheduled jobs can be activated", %{state: state} do
      at = DateTime.from_naive!(~N[2017-08-17T12:23:34.0Z], "Etc/UTC")
      Repo.insert!(JobQueue.new(%{}, schedule: at))

      assert {:noreply, [%JobQueue{}], %{demand: 9}} =
               Producer.handle_info(:poll, %{state | demand: 10})
    end

    test "When always_dispatch_jobs_on_poll is true", %{state: state} do
      Repo.insert!(JobQueue.new(%{}))

      assert {:noreply, [%JobQueue{}], %{demand: 9}} =
               Producer.handle_info(:poll, %{
                 state
                 | demand: 10,
                   always_dispatch_jobs_on_poll: true
               })
    end

    test "When always_dispatch_jobs_on_poll is false", %{state: state} do
      Repo.insert!(JobQueue.new(%{}))

      assert {:noreply, [], %{demand: 10}} =
               Producer.handle_info(:poll, %{
                 state
                 | demand: 10,
                   always_dispatch_jobs_on_poll: false
               })
    end
  end

  describe "handle_info :notify" do
    test "when demand=0", %{state: state} do
      Repo.insert!(JobQueue.new(%{}))

      assert {:noreply, [], ^state} =
               Producer.handle_info({:notification, self(), make_ref(), "jobs", ""}, state)
    end

    test "when demand is buffered", %{state: state} do
      Repo.insert!(JobQueue.new(%{}))
      message = {:notification, self(), make_ref(), "jobs", ""}

      assert {:noreply, [%JobQueue{}], %{demand: 9}} =
               Producer.handle_info(message, %{state | demand: 10})
    end
  end

  describe "handle_demand" do
    test "when jobs available", %{state: state} do
      for _ <- 1..3, do: Repo.insert!(JobQueue.new(%{}))

      assert {:noreply, [%JobQueue{}, %JobQueue{}, %JobQueue{}], %{demand: 2}} =
               Producer.handle_demand(5, state)
    end

    test "when no jobs available", %{state: state} do
      assert {:noreply, [], %{demand: 5}} = Producer.handle_demand(5, state)
    end
  end
end
