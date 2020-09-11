defmodule EctoJob.SupervisorTest do
  use ExUnit.Case
  alias EctoJob.Test.JobQueue

  test "start_link" do
    {:ok, pid} = JobQueue.start_link(repo: EctoJob.Test.Repo, max_demand: 25)

    case EctoJob.Test.Repo.__adapter__() do
      Ecto.Adapters.Postgres ->
        assert [
                 {EctoJob.WorkerSupervisor, _, :supervisor, [EctoJob.WorkerSupervisor]},
                 {EctoJob.Producer, producer_pid, :worker, [EctoJob.Producer]},
                 {Postgrex.Notifications, notifications_pid, :worker, [Postgrex.Notifications]}
               ] = Supervisor.which_children(pid)

        assert Process.whereis(JobQueue.Supervisor) == pid
        assert Process.whereis(JobQueue.Notifier) == notifications_pid
        assert Process.whereis(JobQueue.Producer) == producer_pid

      Ecto.Adapters.MyXQL ->
        assert [
                 {EctoJob.WorkerSupervisor, _, :supervisor, [EctoJob.WorkerSupervisor]},
                 {EctoJob.Producer, producer_pid, :worker, [EctoJob.Producer]}
               ] = Supervisor.which_children(pid)

        assert Process.whereis(JobQueue.Supervisor) == pid
        assert Process.whereis(JobQueue.Producer) == producer_pid
    end
  end
end
