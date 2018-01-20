defmodule EctoJob.JobQueue do
  @moduledoc """
  Mixin for defining an Ecto schema for a Job Queue table in the database.

  ## Example

      defmodule MyApp.JobQueue do
        use EctoJob.JobQueue, table_name: "jobs"

        def perform(multi = %Ecto.Multi{}, job = %{}) do
          ...
        end
      end
  """

  alias Ecto.{Changeset, Multi}
  require Ecto.Query, as: Query

  @type repo :: module
  @type schema :: module
  @type state :: String.t
  @type job :: %{
    __struct__: :atom,
    id: integer,
    state: state,
    expires: DateTime.t | nil,
    schedule: DateTime.t,
    attempt: integer,
    max_attempts: integer,
    params: map,
    notify: String.t | nil,
    updated_at: DateTime.t,
    inserted_at: DateTime.t
  }

  @callback perform(Multi.t, map) :: term

  defmacro __using__(table_name: table_name) do
    quote do
      use Ecto.Schema
      @behaviour EctoJob.JobQueue

      schema unquote(table_name) do
        field :state, :string          # SCHEDULED, RESERVED, IN_PROGRESS, FAILED
        field :expires, :utc_datetime  # Time at which reserved/in_progress jobs can be reset to SCHEDULED
        field :schedule, :utc_datetime # Time at which a scheduled job can be reserved
        field :attempt, :integer       # Counter for number of attempts for this job
        field :max_attempts, :integer  # Maximum attempts before this job is FAILED
        field :params, :map            # Job params, serialized as JSONB
        field :notify, :string         # Payload used to notify that job has completed
        timestamps()
      end

      @doc """
      Supervisor child_spec for use with Elixir 1.5+
      See `start_link` for available options
      """
      @spec child_spec(Keyword.t) :: Supervisor.child_spec
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      @doc """
      Start the JobQueue.Supervisor using the current module as the queue schema.
      """
      @spec start_link([repo: EctoJob.JobQueue.repo, max_demand: integer]) :: {:ok, pid}
      def start_link(repo: repo, max_demand: max_demand) do
        EctoJob.Supervisor.start_link(repo: repo, schema: __MODULE__, max_demand: max_demand)
      end

      @doc """
      Create a new #{__MODULE__} instance with the given job params.

      Params will be serialized as JSON, so

      Options:

       - `:schedule` : runs the job at the given `%DateTime{}`
       - `:max_attempts` : the maximum attempts for this job
      """
      @spec new(map, Keyword.t) :: EctoJob.JobQueue.job
      def new(params = %{}, opts \\ []) do
        %__MODULE__{
          state: (if opts[:schedule], do: "SCHEDULED", else: "AVAILABLE"),
          expires: nil,
          schedule: Keyword.get(opts, :schedule, DateTime.utc_now()),
          attempt: 0,
          max_attempts: opts[:max_attempts],
          params: params,
          notify: opts[:notify]
        }
      end

      @doc """
      Adds a job to an Ecto.Multi, returning the new Ecto.Multi.
      This is the preferred method of enqueueing jobs along side other application updates.

      ## Example:

          Ecto.Multi.new()
          |> Ecto.Multi.insert(create_new_user_changeset(user_params))
          |> MyApp.Job.enqueue("send_welcome_email", %{"type" => "SendWelcomeEmail", "user" => user_params})
          |> MyApp.Repo.transaction()
      """
      @spec enqueue(Multi.t, term, map, Keyword.t) :: Multi.t
      def enqueue(multi = %Multi{}, name,  params, opts \\ []) do
        Multi.insert(multi, name, new(params, opts))
      end
    end
  end

  @doc """
  Updates all jobs in the SCHEDULED state with scheduled time <= now to "AVAILABLE" state.
  Returns the number of jobs updated.
  """
  @spec activate_scheduled_jobs(repo, schema, DateTime.t) :: integer
  def activate_scheduled_jobs(repo, schema, now = %DateTime{}) do
    {count, _} = repo.update_all(
      (Query.from job in schema,
      where: job.state == "SCHEDULED",
      where: job.schedule <= ^now),
      [set: [state: "AVAILABLE", updated_at: now]])

    count
  end

  @doc """
  Updates all jobs in the RESERVED or IN_PROGRESS state with expires time <= now to "AVAILABLE" state.
  Returns the number of jobs updated.
  """
  @spec activate_expired_jobs(repo, schema, DateTime.t) :: integer
  def activate_expired_jobs(repo, schema, now = %DateTime{}) do
    {count, _} = repo.update_all(
      (Query.from job in schema,
      where: job.state in ["RESERVED", "IN_PROGRESS"],
      where: job.attempt < job.max_attempts,
      where: job.expires < ^now),
      [set: [state: "AVAILABLE", expires: nil, updated_at: now]])

    count
  end

  @doc """
  Updates all jobs that have been attempted the maximum number of times to FAILED.
  Returns the number of jobs updated.
  """
  @spec fail_expired_jobs_at_max_attempts(repo, schema, DateTime.t) :: integer
  def fail_expired_jobs_at_max_attempts(repo, schema, now = %DateTime{}) do
    {count, _} = repo.update_all(
      (Query.from job in schema,
      where: job.state in ["IN_PROGRESS"],
      where: job.attempt >= job.max_attempts,
      where: job.expires < ^now),
      [set: [state: "FAILED", expires: nil, updated_at: now]])

    count
  end

  @doc """
  Updates a batch of jobs in AVAILABLE state ot RESERVED state with an expiry.
  The batch size is determined by `demand`.
  returns {count, updated_jobs} tuple.
  """
  @spec reserve_available_jobs(repo, schema, integer, DateTime.t) :: {integer, [job]}
  def reserve_available_jobs(repo, schema, demand, now = %DateTime{}) do
    repo.update_all(
      available_jobs(schema, demand),
      [set: [state: "RESERVED", expires: reservation_expiry(now), updated_at: now]],
      returning: true)
  end

  @doc """
  Builds a query for a batch of available jobs.
  The batch size is determined by `demand`
  """
  @spec available_jobs(schema, integer) :: Ecto.Query.t
  def available_jobs(schema, demand) do
    query =
      Query.from job in schema,
      where: job.state == "AVAILABLE",
      order_by: [asc: job.schedule],
      lock: "FOR UPDATE SKIP LOCKED",
      limit: ^demand,
      select: [:id]

    # Ecto doesn't support subquery in where clause, so use join as workaround
    Query.from job in schema,
    join: x in subquery(query), on: job.id == x.id
  end

  @doc """
  Computes the expiry time for a job reservation to be held, given the current time.
  """
  @spec reservation_expiry(DateTime.t) :: DateTime.t
  def reservation_expiry(now = %DateTime{}) do
    now
    |> DateTime.to_unix()
    |> Kernel.+(300)
    |> DateTime.from_unix!()
  end

  @doc """
  Transitions a job from RESERVED to IN_PROGRESS.

  Confirms that the job reservation hasn't expired by checking:

   - The attempt counter hasn't been changed
   - The state is still RESERVED
   - The expiry time is in the future

  Updates the state to "IN_PROGRESS", increments the attempt counter, and sets an
  expiry time, proportional to the attempt counter.

  Returns {:ok, job} when sucessful, {:error, :expired} otherwise.
  """
  @spec update_job_in_progress(repo, job, DateTime.t) :: {:ok, job} | {:error, :expired}
  def update_job_in_progress(repo, job = %schema{}, now) do
    {count, results} =
      repo.update_all(
        (Query.from j in schema,
        where: j.id == ^(job.id),
        where: j.attempt == (^job.attempt),
        where: j.state == "RESERVED",
        where: j.expires >= ^now),
        [set: [attempt: job.attempt + 1,
               state: "IN_PROGRESS",
               expires: progress_expiry(now, job.attempt + 1),
               updated_at: now]],
        [returning: true])

    case {count, results} do
      {0, _} -> {:error, :expired}
      {1, [job]} -> {:ok, job}
    end
  end

  @doc """
  Computes the expiry time for an IN_PROGRESS job based on the current time and attempt counter
  """
  @spec progress_expiry(DateTime.t, integer) :: DateTime.t
  def progress_expiry(now, attempt) do
    now
    |> DateTime.to_unix()
    |> Kernel.+(300 * attempt)
    |> DateTime.from_unix!()
  end

  @doc """
  Creates an Ecto.Multi struct with the command to delete the given job from the queue.
  This will be passed as the first argument to the user supplied callback function.
  """
  @spec initial_multi(job) :: Multi.t
  def initial_multi(job) do
    Multi.new()
    |> Multi.delete("delete_job_#{job.id}", delete_job_changeset(job))
  end

  @doc """
  Creates a changeset that will delete a job, confirming that the attempt counter hasn't been
  increased by another worker process.
  """
  @spec delete_job_changeset(job) :: Changeset.t
  def delete_job_changeset(job) do
    job
    |> Changeset.change()
    |> Changeset.optimistic_lock(:attempt)
  end
end
