defmodule SimpleDemo.JobQueue do
  require Logger
  use EctoJob.JobQueue, table_name: "jobs"
  alias Ecto.Multi
  require IEx

  @doc "send some payload to test"
  def enqueue(payload) do
    job = %{"type" => "test", "payload" => payload}

    Ecto.Multi.new()
      |> SimpleDemo.JobQueue.enqueue(:some_job, job)
      |> SimpleDemo.Repo.transaction()
  end



  def perform(multi = %Ecto.Multi{}, job = %{"type" => "test", "payload" => payload}) do
    multi
      |> Ecto.Multi.run(:send, fn _ -> make_some_work(payload)  end)
      |> SimpleDemo.Repo.transaction()

  end

  def make_some_work(payload) do
    IO.inspect("I am working on #{payload} now")
    {:ok, :nothing}
  end

end
