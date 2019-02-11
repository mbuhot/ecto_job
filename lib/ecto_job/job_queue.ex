defmodule EctoJob.JobQueue do
  @moduledoc """
  Mixin for defining an Ecto schema for a Job Queue table in the database.

  ## Example

      defmodule MyApp.JobQueue do
        use EctoJob.JobQueue, table_name: "jobs"

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
   - `"RETRYING"`: The job has failed and it's waiting for a retry
   - `"FAILED"`: The job has exceeded the `max_attempts` and will not be retried again
  """
  @type state :: String.t()

  @typedoc """
  A job `Ecto.Schema` struct.
  """
  @type job :: %{
          __struct__: module,
          id: integer | nil,
          state: state,
          expires: DateTime.t() | nil,
          schedule: DateTime.t() | nil,
          attempt: integer(),
          max_attempts: integer | nil,
          params: map(),
          notify: String.t() | nil,
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

  defmacro __using__(table_name: table_name) do
    quote do
      use Ecto.Schema
      @behaviour EctoJob.JobQueue

      schema unquote(table_name) do
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
          notify: opts[:notify]
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
    end
  end

  @doc """
  Updates all jobs in the `"SCHEDULED"` and `"RETRYING"` state with scheduled time <= now to `"AVAILABLE"` state.

  Returns the number of jobs updated.
  """
  @spec activate_scheduled_jobs(repo, schema, DateTime.t()) :: integer
  def activate_scheduled_jobs(repo, schema, now = %DateTime{}) do
    {count, _} =
      repo.update_all(
        Query.from(
          job in schema,
          where: job.state in ["SCHEDULED", "RETRYING"],
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
  Updates all RETRYING jobs that have been attempted the maximum number of times to `"FAILED"`.

  Returns the number of jobs updated.
  """
  @spec fail_retrying_jobs_at_max_attempts(repo, schema, DateTime.t()) :: integer
  def fail_retrying_jobs_at_max_attempts(repo, schema, now = %DateTime{}) do
    {count, _} =
      repo.update_all(
        Query.from(
          job in schema,
          where: job.state in ["RETRYING"],
          where: job.attempt >= job.max_attempts
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
    repo.update_all(
      available_jobs(schema, demand),
      set: [state: "RESERVED", expires: reservation_expiry(now, timeout_ms), updated_at: now]
    )
  end

  @doc """
  Builds a query for a batch of available jobs.

  The batch size is determined by `demand`
  """
  @spec available_jobs(schema, integer) :: Ecto.Query.t()
  def available_jobs(schema, demand) do
    query =
      Query.from(
        job in schema,
        where: job.state == "AVAILABLE",
        order_by: [asc: job.schedule, asc: job.id],
        lock: "FOR UPDATE SKIP LOCKED",
        limit: ^demand,
        select: [:id]
      )

    # Ecto doesn't support subquery in where clause, so use join as workaround
    Query.from(job in schema, join: x in subquery(query), on: job.id == x.id, select: job)
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
          expires: increase_time(now, job.attempt + 1, timeout_ms),
          updated_at: now
        ]
      )

    case {count, results} do
      {0, _} -> {:error, :expired}
      {1, [job]} -> {:ok, job}
    end
  end

  @doc """
  Transitions a job from `"IN_PROGRESS"` to `"RETRYING"`.

  Updates the state to `"RETRYING"` and changes the schedule time to
  differentiate an expired job from one that had an exception or an error.

  """
  @spec update_job_to_retrying(repo, job, DateTime.t(), integer) ::
          {:ok, Ecto.Schema.t()} | {:error, String.t}
  def update_job_to_retrying(repo, job  = %schema{}, now, timeout_ms) do
    {count, results} =
      repo.update_all(
        Query.from(
          j in schema,
          where: j.id == ^job.id,
          where: j.state == "IN_PROGRESS",
          select: j
        ),
        [
          set: [
            state: "RETRYING",
            schedule: increase_time(now, job.attempt + 1, timeout_ms),
            updated_at: now
          ]
        ]
      )

    case {count, results} do
      {0, _} -> {:error, :wrong_state_when_retrying}
      {1, [job]} -> {:ok, job}
    end
  end

  @doc """
  Computes the expiry time for an `"IN_PROGRESS"` and schedule time of "RETRYING" jobs based on the current time and attempt counter.
  """
  @spec increase_time(DateTime.t(), integer, integer) :: DateTime.t()
  def increase_time(now = %DateTime{}, attempt, timeout_ms) do
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
