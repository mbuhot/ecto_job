defmodule EctoJob.JobQueue.Helpers do
  @moduledoc false

  def __serialize_params__(params, :map) when is_map(params), do: params
  def __serialize_params__(params, :binary), do: :erlang.term_to_binary(params)
end
