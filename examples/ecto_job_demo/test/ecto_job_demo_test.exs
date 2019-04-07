defmodule EctoJobDemoTest do
  use ExUnit.Case, async: false
  doctest EctoJobDemo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(EctoJobDemo.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(EctoJobDemo.Repo, {:shared, self()})
    start_supervised!({EctoJobDemo.JobQueue, [repo: EctoJobDemo.Repo, max_demand: 100]})
    :ok
  end

  test "Run jobs from a test" do
    Enum.reduce(1..10, Ecto.Multi.new(), fn i, multi ->
      multi
      |> EctoJobDemo.JobQueue.enqueue(i, %{hello: i})
    end)
    |> EctoJobDemo.Repo.transaction()

    send(EctoJobDemo.JobQueue.Producer, :poll)

    wait_for_jobs_to_complete()
  end

  def wait_for_jobs_to_complete() do
    if EctoJobDemo.Repo.exists?(EctoJobDemo.JobQueue) do
      Process.sleep(100)
      wait_for_jobs_to_complete()
    end
  end
end
