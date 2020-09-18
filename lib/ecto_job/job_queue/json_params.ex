defmodule EctoJob.JobQueue.JsonParams do
  @moduledoc """
  Job queue parameters as Json
  """
  use Ecto.Type

  def type, do: :map

  def cast(data) when is_map(data), do: {:ok, data}

  def cast(_), do: :error

  def load(data) when is_map(data), do: {:ok, data}

  def load(_), do: :error

  def dump(data) when is_map(data), do: {:ok, data}

  def dump(_), do: :error
end
