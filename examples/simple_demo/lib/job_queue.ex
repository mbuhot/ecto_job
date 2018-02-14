defmodule SimpleDemo.JobQueue do
  require Logger
  use EctoJob.JobQueue, table_name: "jobs"
  alias Ecto.Multi
  require IEx

  @type payload :: map()
  @doc "test our job TODO: move to test"
  def enqueue(payload) do
    job = %{"type" => "test", "payload" => "jim@jim.com"}

    Ecto.Multi.new()
      |> SimpleDemo.JobQueue.enqueue(:invoice_job, job)
      |> SimpleDemo.Repo.transaction()
  end


  @doc """
  The actual work to be donw here is from this file.
  """

  def perform(multi = %Ecto.Multi{}, job = %{"type" => "test", "payload" => payload}) do
    multi
      |> Ecto.Multi.run(:send, fn _ -> make_some_work(payload)  end)
      |> BigData.Repo.transaction()

  end

  def make_some_work(payload), do:
    IO.inspect("I am working on #{payload} now")

end
