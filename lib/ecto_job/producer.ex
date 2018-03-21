defmodule EctoJob.Producer do
  @moduledoc """
  GenStage producer responsible for reserving available jobs from a job queue, and
  passing them on to the consumer module.

  The GenStage will buffer demand when there are insufficient jobs available in the
  database.

  Installs a timer to check for expired jobs, and uses a Postgrex.Notifications listener
  to dispatch jobs immediately when new jobs are inserted into the database and there is
  pending demand.
  """

  use GenStage
  alias EctoJob.JobQueue
  alias Postgrex.Notifications
  require Logger

  @type repo :: module
  @type schema :: module
  @type notifier :: pid

  defmodule State do
    @moduledoc """
    Internal state of the Producer GenStage
    """
    @enforce_keys [:repo, :schema, :notifier, :demand, :clock]
    defstruct [:repo, :schema, :notifier, :demand, :clock]

    @type t :: %__MODULE__{
            repo: EctoJob.Producer.repo(),
            schema: EctoJob.Producer.schema(),
            notifier: EctoJob.Producer.notifier(),
            demand: integer,
            clock: (() -> DateTime.t())
          }
  end

  @doc """
  Starts the producer GenStage process.
   - `name` : The process name to register this GenStage as
   - `repo` : The Ecto Repo module to user for querying
   - `schema` : The EctoJob.JobQueue module to query
   - `notifier` : The name of the `Postgrex.Notifications` notifier process
  """
  @spec start_link(name: atom, repo: repo, schema: schema, notifier: atom) :: {:ok, pid}
  def start_link(name: name, repo: repo, schema: schema, notifier: notifier) do
    GenStage.start_link(
      __MODULE__,
      %State{
        repo: repo,
        schema: schema,
        notifier: Process.whereis(notifier),
        demand: 0,
        clock: &DateTime.utc_now/0
      },
      name: name
    )
  end

  @doc """
  Starts the sweeper timer to activate scheduled/expired jobs and starts listening for new job notifications.
  """
  @impl true
  @spec init(State.t()) :: {:producer, State.t()}
  def init(state = %State{notifier: notifier, schema: schema}) do
    _ = start_timer()
    _ = start_listener(notifier, schema)
    {:producer, state}
  end

  # Starts the sweeper timer to activate scheduled/expired jobs
  @spec start_timer() :: {:ok, :timer.tref()}
  defp start_timer do
    {:ok, _ref} = :timer.send_interval(Application.get_env(:ecto_job, :poll_interval, 60_000), :poll)
  end

  # Starts listening to notifications from postgrex for new jobs
  @spec start_listener(notifier, schema) :: reference
  defp start_listener(notifier, schema) do
    table_name = schema.__schema__(:source)
    Notifications.listen!(notifier, table_name)
  end

  @doc """
  Messages from the timer and the notifications listener will be handled in `handle_info`.

  If there is no pending demand for jobs, then all messages are ignored.
  `:poll` messages will attempt to activate jobs, and dispatch them according to current demand.
  `:notification` messages will dispatch any active jobs according to current demand.
  """
  @impl true
  @spec handle_info(term, State.t()) :: {:noreply, [JobQueue.job()], State.t()}
  def handle_info(_, state = %State{demand: 0}) do
    {:noreply, [], state}
  end

  def handle_info(:poll, state = %State{repo: repo, schema: schema, clock: clock}) do
    now = clock.()
    _ = JobQueue.fail_expired_jobs_at_max_attempts(repo, schema, now)

    if activate_jobs(repo, schema, now) > 0 do
      dispatch_jobs(state, now)
    else
      {:noreply, [], state}
    end
  end

  def handle_info({:notification, _pid, _ref, _channel, _payload}, state = %State{clock: clock}) do
    dispatch_jobs(state, clock.())
  end

  @doc """
  Dispatch jobs according to the new demand plus any buffered demand.
  """
  @impl true
  @spec handle_demand(integer, State.t()) :: {:noreply, [JobQueue.job()], State.t()}
  def handle_demand(demand, state = %State{demand: buffered_demand, clock: clock}) do
    dispatch_jobs(%{state | demand: demand + buffered_demand}, clock.())
  end

  # Acivate sheduled jobs and expired jobs, returning the number of jobs activated
  @spec activate_jobs(repo, schema, DateTime.t()) :: integer
  defp activate_jobs(repo, schema, now = %DateTime{}) do
    JobQueue.activate_scheduled_jobs(repo, schema, now) +
      JobQueue.activate_expired_jobs(repo, schema, now)
  end

  # Reserve jobs according to demand, and construct the GenState reply tuple
  @spec dispatch_jobs(State.t(), DateTime.t()) :: {:noreply, [JobQueue.job()], State.t()}
  defp dispatch_jobs(state = %State{repo: repo, schema: schema, demand: demand}, now) do
    {count, jobs} = JobQueue.reserve_available_jobs(repo, schema, demand, now)
    {:noreply, jobs, %{state | demand: demand - count}}
  end
end
