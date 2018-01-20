defmodule EctoJobDemo.CLI do
  def main([n, mode]) do
    n
    |> Integer.parse()
    |> elem(0)
    |> enqueue_jobs(mode)

    IO.gets("")
  end

  defp enqueue_jobs(n, "ecto_job") do
    Enum.each(1..n, fn i ->
      {EctoJobDemo, :hello, [i]}
      |> EctoJobDemo.JobQueue.new()
      |> EctoJobDemo.Repo.insert!()
    end)
  end

  defp enqueue_jobs(n, "exq") do
    Enum.each(1..n, fn i ->
      Exq.enqueue(Exq.Enqueuer, "default", EctoJobDemo, [i])
    end)
  end
end
