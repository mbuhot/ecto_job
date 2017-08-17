# EctoJob

A transactional job queue built with Ecto, PostgreSQL and GenStage

## Goals

 - Transactional job processing
 - Retries
 - Scheduled jobs
 - Multiple queues
 - Low latency concurrent processing
 - Avoid frequent database polling
 - Library of functions, not a full OTP application


## Getting Started

Add `:ecto_job` to your `dependencies`

```elixir
  {:ecto_job, github: "mbuhot/ecto_job"}
```

## Installation

Add a migration to install the notification function and create the a job queue table:

```
mix ecto.gen.migration create_job_queue
```

```elixir
defmodule MyApp.Repo.Migrations.CreateJobQueue do
  use Ecto.Migration

  def up do
    EctoJob.Migrations.Install.up()
    EctoJob.Migrations.CreateJobTable.up("jobs")
  end

  def down do
    EctoJob.Migrations.CreateJobTable.down("jobs")
    EctoJob.Migrations.Install.down()
  end
end
```

Add a module for the queue. This will declare an `Ecto.Schema` to use with the table created in the migration and a
start_link function allowing the supervisor to be started conveniently.

```elixir
defmodule MyApp.JobQueue do
  use EctoJob.JobQueue, table_name: "jobs"
end
```

Add your new JobQueue module as a supervisor to the application supervision tree:

```elixir
def start(_type, _args) do
  import Supervisor.Spec

  children = [
    supervisor(MyApp.Repo, []),
    supervisor(MyApp.JobQueue, [[repo: MyApp.Repo, max_demand: 100]])
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end

```

## Usage

Define a function to run, accepting `%Ecto.Multi{}` as the first argument, followed by other application arguments:

```elixir
defmodule MyApp.SendEmail do
  def perform(multi = %Ecto.Multi{}, recipient, body) do
    multi
    |> Ecto.Multi.run(:send, fn _ -> EmailService.send(recipient, body))
    |> Ecto.Multi.insert(:stats, %EmailSendStats{recipient: recipient})
    |> MyApp.Repo.transaction()
  end
end
```

Enqueue jobs:

Directly:
```elixir
{MyApp.SendEmail, :perform, ["joe@gmail.com", "Welcome!"]}
|> MyApp.JobQueue.new()
|> MyApp.Repo.insert()
```

As part of a Multi:
```elixir
Ecto.Multi.new()
|> Ecto.Multi.insert(:add_user, User.insert_changeset(%{name: "Joe", email: "joe@gmail.com"}))
|> MyApp.JobQueue.enqueue(:email_job, &MyApp.SendEmail.perform(&1, "joe@gmail.com", "Welcome!"))
|> MyApp.Repo.transaction()
```


## How it works

Each job queue is represented as a PostgreSQL table and Ecto schema.

Jobs are added to the queue by inserting into the table, using `Ecto.Repo.transaction` to transactionally enqueue jobs with other application updates.

A `GenStage` producer responds to demand for jobs by efficiently pulling jobs from the queue in batches.
When there is insufficient jobs in the queue, the demand for jobs is buffered.

As jobs are inserted into the queue, `pg_notify` notifies the producer that new work is available,
allowing the producer to dispatch jobs immediately if there is pending demand.

A `GenStage` `ConsumerSupervisor` subscribes to the producer, and spawns a new `Task` for each job.

The callback for each job receives an `Ecto.Multi` structure, pre-populated with a `delete`
command to remove the job from the queue.

Application code then add additional commands to the `Ecto.Multi` and submit it to the
`Repo` with a call to `transaction`, ensuring that application updates are performed atomically with the job removal.

Scheduled jobs and Failed jobs are reactivated by polling the database once per minute.

## Job Lifecycle

Jobs scheduled to run at a future time start in the "SCHEDULED" state.
Scheduled jobs transition to "AVAILABLE" after the scheduled time has passed.

Jobs that are intended to run immediately start in an "AVAILABLE" state.

The producer will update a batch of jobs setting the state to "RESERVED", with an expiry of 5 minutes.

Once a consumer is given a job, it increments the attempt counter and updates the state to "IN_PROGRESS", with an expiry of 5 minutes.
If the job is being retried, the expiry will be 5 minutes * the attempt counter.

If successful, the consumer will delete the job from the queue.
If unsuccessful, the job remains in the "IN_PROGRESS" state until it expires.

Jobs in the "RESERVED" or "IN_PROGRESS" state past the expiry time will be returned to the "AVAILABLE" state.

Expired jobs in the "IN_PROGRESS" state with attempts >= MAX_ATTEMPTS move to a "FAILED" state.
Failed jobs are kept in the database so that application developers can handle the failure.
