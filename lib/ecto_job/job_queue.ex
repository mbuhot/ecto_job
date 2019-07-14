defmodule EctoJob.JobQueue do
  @moduledoc """
  Mixin for defining an Ecto schema for a Job Queue table in the database.

  ## Options

  * `:table_name` - (_required_) The name of the job table in the database.
  * `:schema_prefix` - (_optional_) The schema prefix for the table.
  * `:timestamps_opts` - (_optional_) Configures the timestamp fields for the schema (See `Ecto.Schema.timestamps/1`)

  ## Example

      defmodule MyApp.JobQueue do
        use EctoJob.JobQueue, table_name: "jobs", schema_prefix: "my_app"

        @spec perform(Ecto.Multi.t(), map()) :: any()
        def perform(multi, job = %{}) do
          ...
        end
      end
  """

  alias Ecto.{Changeset, Multi}
  require Ecto.Query, as: Query

  @typedoc "An `Ecto.Repo` module name"
  @type repo :: module

  @typedoc "An `Ecto.Schema` module name"
  @type schema :: module

  @typedoc """
  Job State enumeration

   - `"SCHEDULED"`: The job is scheduled to run at a future time
   - `"AVAILABLE"`: The job is availble to be run by the next available worker
   - `"RESERVED"`: The job has been reserved by a worker for execution
   - `"IN_PROGRESS"`: The job is currently being worked
   - `"FAILED"`: The job has exceeded the `max_attempts` and will not be retried again
  """
  @type state :: String.t()

  @typedoc """
  A job `Ecto.Schema` struct.
  """
  @type job :: %{
          __struct__: module,
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer | nil,
          state: state,
          expires: DateTime.t() | nil,
          schedule: DateTime.t() | nil,
          attempt: integer,
          max_attempts: integer | nil,
          params: map(),
          notify: String.t() | nil,
          priority: integer | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Job execution callback to be implemented by each `JobQueue` module.

  ## Example

      @impl true
      def perform(multi, params = %{"type" => "new_user"}), do: NewUser.perform(multi, params)
      def perform(multi, params = %{"type" => "sync_crm"}), do: SyncCRM.perform(multi, params)
  """
  @callback perform(multi :: Multi.t(), params :: map) :: any()

  defmacro __using__(opts) do
    table_name = Keyword.fetch!(opts, :table_name)
    schema_prefix = Keyword.get(opts, :schema_prefix)
    timestamps_opts = Keyword.get(opts, :timestamps_opts)

    quote bind_quoted: [
            table_name: table_name,
            schema_prefix: schema_prefix,
            timestamps_opts: timestamps_opts
          ] do
      use Ecto.Schema
      @behaviour EctoJob.JobQueue

      if schema_prefix do
        @schema_prefix schema_prefix
      end

      if timestamps_opts do
        @timestamps_opts timestamps_opts
      end

      schema table_name do
        # SCHEDULED, RESERVED, IN_PROGRESS, FAILED
        field(:state, :string)
        # Time at which reserved/in_progress jobs can be reset to SCHEDULED
        field(:expires, :utc_datetime_usec)
        # Time at which a scheduled job can be reserved
        field(:schedule, :utc_datetime_usec)
        # Counter for number of attempts for this job
        field(:attempt, :integer)
        # Maximum attempts before this job is FAILED
        field(:max_attempts, :integer)
        # Job params, serialized as JSONB
        field(:params, :map)
        # Payload used to notify that job has completed
        field(:notify, :string)
        # Used to prioritize the job execution
        field(:priority, :integer)
        timestamps()
      end

      @doc """
      Supervisor child_spec for use with Elixir 1.5+

      See `EctoJob.Config` for available configuration options.
      """
      @spec child_spec(Keyword.t()) :: Supervisor.child_spec()
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      @doc """
      Start the `JobQueue.Supervisor` using the current module as the queue schema.

      See `EctoJob.Config` for available configuration options.

      ## Example

          MyApp.JobQueue.start_link(repo: MyApp.Repo, max_demand: 25)
      """
      @spec start_link(Keyword.t()) :: {:ok, pid}
      def start_link(opts) do
        config = EctoJob.Config.new(opts)
        EctoJob.Supervisor.start_link(%{config | schema: __MODULE__})
      end

      @doc """
      Create a new `#{__MODULE__}` instance with the given job params.

      Params will be serialized as JSON, so

      Options:

       - `:schedule` : runs the job at the given `%DateTime{}`
       - `:max_attempts` : the maximum attempts for this job
       - `:priority` : the priority of this work, the default value is `0`. Increase this value to decrease priority.
      """
      @spec new(map, Keyword.t()) :: EctoJob.JobQueue.job()
      def new(params = %{}, opts \\ []) do
        %__MODULE__{
          state: if(opts[:schedule], do: "SCHEDULED", else: "AVAILABLE"),
          expires: nil,
          schedule: Keyword.get(opts, :schedule, DateTime.utc_now()),
          attempt: 0,
          max_attempts: opts[:max_attempts],
          params: params,
          notify: opts[:notify],
          priority: Keyword.get(opts, :priority, 0)
        }
      end

      @doc """
      Adds a job to an `Ecto.Multi`, returning the new `Ecto.Multi`.

      This is the preferred method of enqueueing jobs along side other application updates.

      ## Example:

          Ecto.Multi.new()
          |> Ecto.Multi.insert(create_new_user_changeset(user_params))
          |> MyApp.Job.enqueue("send_welcome_email", %{"type" => "SendWelcomeEmail", "user" => user_params})
          |> MyApp.Repo.transaction()
      """
      @spec enqueue(Multi.t(), term, map, Keyword.t()) :: Multi.t()
      def enqueue(multi, name, params, opts \\ []) do
        Multi.insert(multi, name, new(params, opts))
      end

      @doc """
      Requeues failed job by adding to an `Ecto.Multi` update statement,
      which will:
      * set `state` to `SCHEDULED`
      * set `attempt` to `0`
      * set `expires` to `nil`

      ## Example:

          Ecto.Multi.new()
          |> MyApp.Job.requeue("requeue_job", failed_job)
          |> MyApp.Repo.transaction()
      """
      @spec requeue(Multi.t(), term, EctoJob.JobQueue.job()) ::
              Multi.t() | {:error, :non_failed_job}
      def requeue(multi, name, job = %__MODULE__{state: "FAILED"}) do
        job_to_requeue = Changeset.change(job, %{state: "SCHEDULED", attempt: 0, expires: nil})
        Multi.update(multi, name, job_to_requeue)
      end

      def requeue(_, _, _), do: {:error, :non_failed_job}
    end
  end

  @doc """
  Updates all jobs in the `"SCHEDULED"` state with scheduled time <= now to `"AVAILABLE"` state.

  Returns the number of jobs updated.
  """
  @spec activate_scheduled_jobs(repo, schema, DateTime.t()) :: integer
  def activate_scheduled_jobs(repo, schema, now = %DateTime{}) do
    {count, _} =
      repo.update_all(
        Query.from(
          job in schema,
          where: job.state == "SCHEDULED",
          where: job.schedule <= ^now
        ),
        set: [state: "AVAILABLE", updated_at: now]
      )

    count
  end

  @doc """
  Updates all jobs in the `"RESERVED"` or `"IN_PROGRESS"` state with expires time <= now to `"AVAILABLE"` state.

  Returns the number of jobs updated.
  """
  @spec activate_expired_jobs(repo, schema, DateTime.t()) :: integer
  def activate_expired_jobs(repo, schema, now = %DateTime{}) do
    {count, _} =
      repo.update_all(
        Query.from(
          job in schema,
          where: job.state in ["RESERVED", "IN_PROGRESS"],
          where: job.attempt < job.max_attempts,
          where: job.expires < ^now
        ),
        set: [state: "AVAILABLE", expires: nil, updated_at: now]
      )

    count
  end

  @doc """
  Updates all jobs that have been attempted the maximum number of times to `"FAILED"`.

  Returns the number of jobs updated.
  """
  @spec fail_expired_jobs_at_max_attempts(repo, schema, DateTime.t()) :: integer
  def fail_expired_jobs_at_max_attempts(repo, schema, now = %DateTime{}) do
    {count, _} =
      repo.update_all(
        Query.from(
          job in schema,
          where: job.state in ["IN_PROGRESS"],
          where: job.attempt >= job.max_attempts,
          where: job.expires < ^now
        ),
        set: [state: "FAILED", expires: nil, updated_at: now]
      )

    count
  end

  @doc """
  Updates a batch of jobs in `"AVAILABLE"` state to `"RESERVED"` state with a timeout.

  The batch size is determined by `demand`.
  returns `{count, updated_jobs}` tuple.
  """
  @spec reserve_available_jobs(repo, schema, integer, DateTime.t(), integer) :: {integer, [job]}
  def reserve_available_jobs(repo, schema, demand, now = %DateTime{}, timeout_ms) do
    {:ok, result} =
      repo.transaction(fn ->
        # Force the materialization of the claimed Job IDs,
        # otherwise postgres may return more rows than intended.
        # see (https://github.com/feikesteenbergen/demos/blob/master/bugs/update_from_correlated.adoc)
        job_ids = repo.all(available_jobs(schema, demand))

        repo.update_all(
          Query.from(job in schema, where: job.id in ^job_ids, select: job),
          set: [state: "RESERVED", expires: reservation_expiry(now, timeout_ms), updated_at: now]
        )
      end)

    result
  end

  @doc """
  Builds a query for a batch of available jobs.

  The batch size is determined by `demand`
  """
  @spec available_jobs(schema, integer) :: Ecto.Query.t()
  def available_jobs(schema, demand) do
    Query.from(
      job in schema,
      where: job.state == "AVAILABLE",
      order_by: [asc: job.priority, asc: job.schedule, asc: job.id],
      lock: "FOR UPDATE SKIP LOCKED",
      limit: ^demand,
      select: job.id
    )
  end

  @doc """
  Computes the expiry time for a job reservation to be held, given the current time.
  """
  @spec reservation_expiry(DateTime.t(), integer) :: DateTime.t()
  def reservation_expiry(now = %DateTime{}, timeout_ms) do
    timeout_ms |> Integer.floor_div(1000) |> advance_seconds(now)
  end

  @doc """
  Transitions a job from `"RESERVED"` to `"IN_PROGRESS"`.

  Confirms that the job reservation hasn't expired by checking:

   - The attempt counter hasn't been changed
   - The state is still `"RESERVED"`
   - The expiry time is in the future

  Updates the state to `"IN_PROGRESS"`, increments the attempt counter, and sets a
  timeout proportional to the attempt counter and the expiry_timeout, which defaults to
  300_000 ms (5 minutes) unless otherwise configured.

  Returns `{:ok, job}` when sucessful, `{:error, :expired}` otherwise.
  """
  @spec update_job_in_progress(repo, job, DateTime.t(), integer) ::
          {:ok, job} | {:error, :expired}
  def update_job_in_progress(repo, job = %schema{}, now, timeout_ms) do
    {count, results} =
      repo.update_all(
        Query.from(
          j in schema,
          where: j.id == ^job.id,
          where: j.attempt == ^job.attempt,
          where: j.state == "RESERVED",
          where: j.expires >= ^now,
          select: j
        ),
        set: [
          attempt: job.attempt + 1,
          state: "IN_PROGRESS",
          expires: progress_expiry(now, job.attempt + 1, timeout_ms),
          updated_at: now
        ]
      )

    case {count, results} do
      {0, _} -> {:error, :expired}
      {1, [job]} -> {:ok, job}
    end
  end

  @doc """
  Computes the expiry time for an `"IN_PROGRESS"` job based on the current time and attempt counter.
  """
  @spec progress_expiry(DateTime.t(), integer, integer) :: DateTime.t()
  def progress_expiry(now = %DateTime{}, attempt, timeout_ms) do
    timeout_ms |> Kernel.*(attempt) |> Integer.floor_div(1000) |> advance_seconds(now)
  end

  @doc """
  Creates an `Ecto.Multi` struct with the command to delete the given job from the queue.

  This will be passed as the first argument to the user supplied callback function.
  """
  @spec initial_multi(job) :: Multi.t()
  def initial_multi(job) do
    Multi.new()
    |> Multi.delete("delete_job_#{job.id}", delete_job_changeset(job))
  end

  @doc """
  Creates an `Ecto.Changeset` that will delete a job, confirming that the attempt counter hasn't been increased by another worker process.
  """
  @spec delete_job_changeset(job) :: Changeset.t()
  def delete_job_changeset(job) do
    job
    |> Changeset.change()
    |> Changeset.optimistic_lock(:attempt)
  end

  defp advance_seconds(seconds, start_time) do
    start_time
    |> DateTime.to_unix()
    |> Kernel.+(seconds)
    |> DateTime.from_unix!()
  end
end
