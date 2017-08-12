defmodule EctoJob.JobQueue do
  require Ecto.Query, as: Query

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

      def enqueue(multi = %Ecto.Multi{}, name,  work, opts \\ []) do
        Ecto.Multi.insert(multi, name, new(work, opts))
      end
    end
  end

  def perform(multi, func) do
    func.(multi)
  end

  def activate_scheduled_jobs(repo, schema, now = %DateTime{}) do
    {count, _} = repo.update_all(
      Query.from(job in schema,
      where: job.state == "SCHEDULED",
      where: job.schedule <= ^now),
      [set: [state: "AVAILABLE"]])

    count
  end

  def activate_expired_jobs(repo, schema, now) do
    {count, _} = repo.update_all(
      Query.from(job in schema,
      where: job.state in ["RESERVED", "IN_PROGRESS"],
      where: job.expires < ^now),
      [set: [state: "AVAILABLE", expires: nil]])

    count
  end

  def reserve_available_jobs(repo, schema, demand, now = %DateTime{}) do
    repo.update_all(
      available_jobs(schema, demand),
      [set: [state: "RESERVED", expires: reservation_expiry(now)]],
      returning: true)
  end

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

  def reservation_expiry(now = %DateTime{}) do
    now
    |> DateTime.to_unix()
    |> Kernel.+(300)
    |> DateTime.from_unix!()
  end

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

  def progress_expiry(now, attempt) do
    now
    |> DateTime.to_unix()
    |> Kernel.+(300 * attempt)
    |> DateTime.from_unix!()
  end

  def deserialize_job_args(job) do
    {
      String.to_existing_atom(job.module),
      String.to_existing_atom(job.function),
      [initial_multi(job) | :erlang.binary_to_term(job.arguments)]
    }
  end

  def initial_multi(job) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete("delete_job_#{job.id}", delete_job_changeset(job))
  end

  def delete_job_changeset(job) do
    job
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.optimistic_lock(:attempt)
  end
end
