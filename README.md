[![Build Status](https://travis-ci.org/mbuhot/ecto_job.svg?branch=master)](https://travis-ci.org/mbuhot/ecto_job)
[![Hex.pm](https://img.shields.io/hexpm/v/ecto_job.svg)](https://hex.pm/packages/ecto_job)
[![HexDocs](https://img.shields.io/badge/api-docs-yellow.svg)](https://hexdocs.pm/ecto_job/)
[![Inline docs](http://inch-ci.org/github/mbuhot/ecto_job.svg?branch=master&style=flat)](http://inch-ci.org/github/mbuhot/ecto_job)
[![License](https://img.shields.io/hexpm/l/ecto_job.svg)](https://github.com/mbuhot/ecto_job/blob/master/LICENSE)

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
  {:ecto_job, "~> 3.0"}
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

### Upgrading pre-existent Ecto Job to 3.x.x version

To upgrade your project to 3.x.x version of ecto job you must add a migration to update the pre-existent job queue tables:

```
mix ecto.gen.migration update_job_queue
```

```elixir
defmodule MyApp.Repo.Migrations.UpdateJobQueue do
  use Ecto.Migration

  def up do
    EctoJob.Migrations.AddPriorityToJobTable.up("jobs")
  end

  def down do
    EctoJob.Migrations.AddPriorityToJobTable.down("jobs")
  end
end
```

Add a module for the queue, mix in `EctoJob.JobQueue`.
This will declare an `Ecto.Schema` to use with the table created in the migration, and a `start_link` function allowing the worker supervision tree to be started conveniently.

```elixir
defmodule MyApp.JobQueue do
  use EctoJob.JobQueue, table_name: "jobs"
end
```

Add `perform/2` function to the job queue module, this is where jobs from the queue will be dispatched.

```elixir
defmodule MyApp.JobQueue do
  use EctoJob.JobQueue, table_name: "jobs"

  def perform(multi = %Ecto.Multi{}, job = %{}) do
    ... job logic here ...
  end
end
```

Add your new `JobQueue` module to the application supervision tree to run the worker supervisor:

```elixir
def start(_type, _args) do
  import Supervisor.Spec

  children = [
    MyApp.Repo,
    {MyApp.JobQueue, repo: MyApp.Repo, max_demand: 100}
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

If you want to run the workers on a separate node to the enqueuers, just leave your `JobQueue` module out of the supervision tree.

## Usage

### Enqueueing jobs

Jobs are Ecto schemas, with each queue backed by a different table.
A job can be inserted into the Repo directly by constructing a job with the `new/2` function:

```elixir
%{"type" => "SendEmail", "address" => "joe@gmail.com", "body" => "Welcome!"}
|> MyApp.JobQueue.new()
|> MyApp.Repo.insert()
```

A job can be inserted with optional params:

- `:schedule` : runs the job at the given `%DateTime{}`. The default value is `DateTime.utc_now()`.
- `:max_attempts` : the maximum attempts for this job. The default value is `5`.
- `:priority` : the priority of this work, the default value is `0`. Increase this value to decrease priority.

```elixir
%{"type" => "SendEmail", "address" => "joe@gmail.com", "body" => "Welcome!"}
|> MyApp.JobQueue.new(max_attempts: 10)
|> MyApp.Repo.insert()

%{"type" => "SendEmail", "address" => "mickel@gmail.com", "body" => "Welcome!"}
|> MyApp.JobQueue.new(priority: 1)
|> MyApp.Repo.insert()

%{"type" => "SendEmail", "address" => "jonas@gmail.com", "body" => "Welcome!"}
|> MyApp.JobQueue.new(priority: 2, max_attempts: 2)
|> MyApp.Repo.insert()
```

The primary benefit of `EctoJob` is the ability to enqueue and process jobs transactionally.
To achieve this, a job can be added to an `Ecto.Multi`, along with other application updates, using the `enqueue/3` function:

```elixir
Ecto.Multi.new()
|> Ecto.Multi.insert(:add_user, User.insert_changeset(%{name: "Joe", email: "joe@gmail.com"}))
|> MyApp.JobQueue.enqueue(:email_job, %{"type" => "SendEmail", "address" => "joe@gmail.com", "body" => "Welcome!"})
|> MyApp.Repo.transaction()
```

### Handling Jobs

All jobs sent to a queue are eventually dispatched to the `perform/2` function defined in the queue module.
The first argument supplied is an `Ecto.Multi` which has been initialized with a `delete` operation, marking the job as complete.
The `Ecto.Multi` struct must be passed to the `Ecto.Repo.transaction` function to complete the job, along with any other application updates.

```elixir
defmodule MyApp.JobQueue do
  use EctoJob.JobQueue, table_name: "jobs"

  def perform(multi = %Ecto.Multi{}, job = %{"type" => "SendEmail", "recipient" => recipient, "body" => body}) do
    multi
    |> Ecto.Multi.run(:send, fn _repo, _changes -> EmailService.send(recipient, body) end)
    |> Ecto.Multi.insert(:stats, %EmailSendStats{recipient: recipient})
    |> MyApp.Repo.transaction()
  end
end
```

When a queue handles multiple job types, it is useful to pattern match on the job and delegate to separate modules:

```elixir
defmodule MyApp.JobQueue do
  use EctoJob.JobQueue, table_name: "jobs"

  def perform(multi = %Ecto.Multi{}, job = %{"type" => "SendEmail"}),      do: MyApp.SendEmail.perform(multi, job)
  def perform(multi = %Ecto.Multi{}, job = %{"type" => "CustomerReport"}), do: MyApp.CustomerReport.perform(multi, job)
  def perform(multi = %Ecto.Multi{}, job = %{"type" => "SyncWithCRM"}),    do: MyApp.CRMSync.perform(multi, job)
  ...
end
```
### Options

You can customize how often the table is polled for scheduled jobs.  The default is `60_000` ms.

```
config :ecto_job, :poll_interval, 15_000
```

Control the time for which the job is reserved while waiting for a worker to pick it up, before the poller will make the job available again for dispatch by the producer.  The default is `60_000` ms.

```
config :ecto_job, :reservation_timeout, 15_000
```

Control the timeout for job execution before a job will be made available for retry. Begins when job is picked up by worker. Keep in mind, for jobs that are expected to retry quickly, any configured `execution_timeout` will only retry a job as quickly as the `poll_interval`.  The default is `300_000` ms (5 mins).

```
config :ecto_job, :execution_timeout, 300_000
```

You can control whether logs are on or off and the log level.  The default is `true` and `:info`.

```
config :ecto_job, log: true,
                  log_level: :debug
```

See `EctoJob.Config` for configuration details.

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

The producer will update a batch of jobs setting the state to "RESERVED", with an expiry of 5 minutes unless otherwise configured.

Once a consumer is given a job, it increments the attempt counter and updates the state to "IN_PROGRESS", with an initial timeout configurable as `execution_timeout`, defaulting to 5 minutes.
If the job is being retried, the expiry will be initial timeout * the attempt counter.

If successful, the consumer can delete the job from the queue using the preloaded multi passed to the `perform/2` job handler.
If an exception is raised in the worker or a successful processing attempt fails to successfully commit the preloaded multi, the job is not deleted and remains in the "IN_PROGRESS" state until it expires.

Jobs in the "RESERVED" or "IN_PROGRESS" state past the expiry time will be returned to the "AVAILABLE" state.

Expired jobs in the "IN_PROGRESS" state with attempts >= MAX_ATTEMPTS move to a "FAILED" state.
Failed jobs are kept in the database so that application developers can handle the failure.

## Job Timeouts and Transactional Safety

When performing long-running jobs or when configuring a short execution timeout, keep in mind that a job may be retried before it has finished and the retry has no proactive mechanism to cancel the running job.

In the case that the initial job attempts to finish and commit a result, and the commit includes the preloaded multi passed as the first parameter to `perform/2`, the optimistic lock will fail the transaction.

In the case where the job performs other side effects outside of the transaction such as calls to external APIs or additional database writes, these are suggested to implement other idempotency guarantees, as they will not be rolled back in a failed or duplicated job.
