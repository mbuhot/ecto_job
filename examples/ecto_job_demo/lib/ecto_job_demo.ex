defmodule EctoJobDemo do
  alias Ecto.Multi
  alias EctoJobDemo.Repo

  # function used when calling from ecto_job
  def hello(multi = %Multi{}, name) do
    perform(name)
    Repo.transaction(multi)
  end

  # function used when calling from exq
  def perform(name) do
    IO.puts("Hello #{name}")
  end
end
