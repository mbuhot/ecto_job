defmodule EctoJob.JobQueue do
  @moduledoc """
  Mixin for defining an Ecto schema for a Job Queue table in the database.

  ## Example

      use EctoJob.JobQueue table_name: "jobs"
  """

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
    module: String.t,
    function: String.t,
    arguments: binary,
    updated_at: DateTime.t,
    inserted_at: DateTime.t
  }

  defmacro __using__(table_name: table_name) do
    quote do
      use Ecto.Schema

      schema unquote(table_name) do
        field :state, :string          # SCHEDULED, RESERVED, IN_PROGRESS, FAILED
        field :expires, :utc_datetime  # Time at which reserved/in_progress jobs can be reset to SCHEDULED
        field :schedule, :utc_datetime # Time at which a scheduled job can be reserved
        field :attempt, :integer       # Counter for number of attempts for this job
        field :module, :string         # Module of client code to invoke
        field :function, :string       # Function of client code to invoke
        field :arguments, :binary      # List of function arguments, serialized with `term_to_binary`
        timestamps()
      end

      @type work :: {module, atom, list} | (Ecto.Multi.t -> term)
      @spec new(work, Keyword.t) :: EctoJob.JobQueue.job
      def new(work, opts \\ [])
      def new({mod, func, args}, opts) when is_list(args) do
        %__MODULE__{
          state: (if opts[:schedule], do: "SCHEDULED", else: "AVAILABLE"),
          expires: nil,
          schedule: Keyword.get(opts, :schedule, DateTime.utc_now()),
          attempt: 0,
          module: to_string(mod),
          function: to_string(func),
          arguments: :erlang.term_to_binary(args)
        }
      end
      def new(func, opts) when is_function(func) do
        new({EctoJob.JobQueue, :perform, [func]})
      end

      @spec enqueue(Ecto.Multi.t, term, work, Keyword.t) :: Ecto.Multi.t
      def enqueue(multi = %Ecto.Multi{}, name,  work, opts \\ []) do
        Ecto.Multi.insert(multi, name, new(work, opts))
      end
    end
  end

  @doc """
  Named function to use when a job is enqueued with an anonymous function.
  """
  @spec perform(Ecto.Multi.t, (Ecto.Multi.t -> term)) :: term
  def perform(multi, func) do
    func.(multi)
  end

  @doc """
  Updates all jobs in the SCHEDULED state with scheduled time <= now to "AVAILABLE" state.
  Returns the number of jobs updated.
  """
  @spec activate_scheduled_jobs(repo, schema, DateTime.t) :: integer
  def activate_scheduled_jobs(repo, schema, now = %DateTime{}) do
    {count, _} = repo.update_all(
      Query.from(job in schema,
      where: job.state == "SCHEDULED",
      where: job.schedule <= ^now),
      [set: [state: "AVAILABLE"]])

    count
  end

  @doc """
  Updates all jobs in the RESERVED or IN_PROGRESS state with expires time <= now to "AVAILABLE" state.
  Returns the number of jobs updated.
  """
  @spec activate_expired_jobs(repo, schema, DateTime.t) :: integer
  def activate_expired_jobs(repo, schema, now = %DateTime{}) do
    {count, _} = repo.update_all(
      Query.from(job in schema,
      where: job.state in ["RESERVED", "IN_PROGRESS"],
      where: job.expires < ^now),
      [set: [state: "AVAILABLE", expires: nil]])

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
      [set: [state: "RESERVED", expires: reservation_expiry(now)]],
      returning: true)
  end

  @doc """
  Builds a query for a batch of available jobs.
  The batch size is determined by `demand`
  """
  @spec available_jobs(schema, integer) :: Ecto.Query.t
  def available_jobs(schema, demand) do
    query =
      Query.from(job in schema,
      where: job.state == "AVAILABLE",
      order_by: [asc: job.schedule],
      lock: "FOR UPDATE SKIP LOCKED",
      limit: ^demand,
      select: [:id])

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
  @spec update_job_in_progress(repo, struct, DateTime.t) :: {:ok, job} | {:error, :expired}
  def update_job_in_progress(repo, job = %schema{}, now) do
    {count, results} =
      repo.update_all(
        Query.from(j in schema,
        where: j.id == ^(job.id),
        where: j.attempt == (^job.attempt),
        where: j.state == "RESERVED",
        where: j.expires >= ^now),
        [set: [attempt: job.attempt + 1, state: "IN_PROGRESS", expires: progress_expiry(now, job.attempt)]],
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
  Deserialize job arguments from strings and binary to atoms / and argument list
  """
  @spec deserialize_job_args(job) :: {:ok, {module, atom, list}} | {:error, term}
  def deserialize_job_args(job) do
    with args when is_list(args) <- :erlang.binary_to_term(job.arguments),
         mod <- String.to_existing_atom(job.module),
         func <- String.to_existing_atom(job.function) do
      {:ok, {mod, func, [initial_multi(job) | args]}}
    else
      _ -> {:error, :bad_argument_list}
    end
  end

  @doc """
  Creates an Ecto.Multi struct with the command to delete the given job from the queue.
  This will be passed as the first argument to the user supplied callback function.
  """
  @spec initial_multi(job) :: Ecto.Multi.t
  def initial_multi(job) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete("delete_job_#{job.id}", delete_job_changeset(job))
  end

  @doc """
  Creates a changeset that will delete a job, confirming that the attempt counter hasn't been
  increased by another worker process.
  """
  @spec delete_job_changeset(job) :: Ecto.Changeset.t
  def delete_job_changeset(job) do
    job
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.optimistic_lock(:attempt)
  end
end
