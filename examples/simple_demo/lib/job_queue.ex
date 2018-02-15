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
      |> Ecto.Multi.run(:good_work, fn _ -> make_some_work(payload)  end)
      |> Ecto.Multi.run(:wrong_work, fn _ -> make_a_wrong_work(payload)  end)
      |> SimpleDemo.Repo.transaction()

  end

  def make_some_work(payload) do
    IO.inspect("I am working on #{payload} now")
    {:ok, :nothing}
  end

  def make_a_wrong_work(payload) do
    IO.inspect("I am working on #{payload} now")
    {:error, "I was too lazy... getting better tomorrow"}
  end

end
