defmodule EctoJob.LiveUpdates do
  use GenServer
  @topic inspect(__MODULE__)
  require Ecto.Query, as: Query

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  # message = {calling_module, event, result}
  def notify_live_view(server) do
    GenServer.cast(server, {:notify_live_view})
  end

  def get_pubsub_name(server) do
    GenServer.call(server, :get_pubsub_name)
  end

  def get_all_jobs(server) do
    GenServer.call(server, :get_all_jobs)
  end

  defp topic, do: @topic

  def init(opts) do
    {:ok, opts}
  end

  def handle_call(:get_pubsub_name, _from, state) do
    {:reply, state[:live_view_pubsub_name], state}
  end

  def handle_call(:get_all_jobs, _from, state) do
    query = Query.from(
    job in state[:schema],
      select: [ "id", job.id,
                "state", job.state,
                "expires", job.expires,
                "schedule", job.schedule,
                "attempt", job.attempt,
                "max_attempts", job.max_attempts,
                "params", job.params,
                "notify", job.notify,
                "inserted_at", job.inserted_at,
                "updated_at", job.updated_at],
      order_by: [desc: :updated_at])
    list = state[:repo].all(query)
    jobs = Enum.map(list, fn(job) ->
      job
      |> Enum.chunk_every(2)
      |> Enum.map(fn [a, b] -> {a, b} end)
      |> Map.new
    end)
    {:reply, jobs, state}
  end

  def handle_cast({:notify_live_view}, state) do
    Phoenix.PubSub.broadcast(state[:live_view_pubsub_name], topic(), "update")
    {:noreply, state}
  end

end
