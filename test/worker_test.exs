defmodule EctoJob.WorkerTest do
  use ExUnit.Case, async: false
  alias EctoJob.Test.{JobQueue, Repo}
  alias Ecto.{Changeset, Multi}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(EctoJob.Test.Repo, {:shared, self()})
  end

  test "start_link updates job state and starts Task" do
    expiry = DateTime.from_naive! ~N[2017-08-17T12:23:34.0Z], "Etc/UTC"
    now = DateTime.from_naive! ~N[2017-08-17T12:20:00Z], "Etc/UTC"
    test_process = self()

    job =
      JobQueue.new(&send(test_process, &1))
      |> Map.put(:state, "RESERVED")
      |> Map.put(:expires, expiry)
      |> Repo.insert!()

    {:ok, _pid} = EctoJob.Worker.start_link(Repo, job, now)

    assert_receive multi = %Multi{}
    assert [{"delete_job_"<>_, {:delete, %Changeset{data: %JobQueue{}}, []}}] = Multi.to_list(multi)
  end
end
