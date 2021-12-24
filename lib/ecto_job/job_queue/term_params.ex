defmodule EctoJob.JobQueue.TermParams do
  @moduledoc """
  Job queue parameters as JSON.
  """
  use Ecto.Type

  def type, do: :binary

  def cast(data), do: {:ok, data}

  def load(data) when is_binary(data) do
    {:ok, :erlang.binary_to_term(data)}
  rescue
    ArgumentError -> :error
  end

  def load(_), do: :error

  def dump(data) do
    {:ok, :erlang.term_to_binary(data)}
  rescue
    _ -> :error
  end
end
