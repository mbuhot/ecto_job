# 3.0.0

Version 3.0 adds support for prioritizing jobs within each job queue.
The `priority` option can be given when creating a Job:

```elixir
%{"type" => "SendEmail", "address" => "jonas@gmail.com", "body" => "Welcome!"}
|> MyApp.JobQueue.new(priority: 2, max_attempts: 2)
|> MyApp.Repo.insert()
```

Lower numbers run first, the default value is 0.

Thanks to [ramondelemos](https://github.com/ramondelemos) for contibuting this feature!

[#45](https://github.com/mbuhot/ecto_job/pull/45) - [gabriel128](https://github.com/gabriel128) Failed jobs will retry before the full `execution_timeout` when an error occurs. By default the first retry will occur 30 seconds after failure.

Thanks to [gabriel128](https://github.com/gabriel128) for contributing this feature!

### Migrating to 3.0

To upgrade to version 3.0 you must add a migration to update the pre-existent job queue tables:

```
mix ecto.gen.migration update_job_queue
```

```elixir
defmodule MyApp.Repo.Migrations.UpdateJobQueue do
  use Ecto.Migration
  @ecto_job_version 3

  def up do
    EctoJob.Migrations.UpdateJobTable.up(@ecto_job_version, "jobs")
  end
  def down do
    EctoJob.Migrations.UpdateJobTable.down(@ecto_job_version, "jobs")
  end
end
```


# 2.1.0

Version 2.1 add support for requeing jobs, fixes to the job reservation algorithm and dialyzer warnings.

[#34](https://github.com/mbuhot/ecto_job/pull/34) - [mkorszun](https://github.com/mkorszun) New API to requeue a failed job :

Requeuing will:

* set `state` to `SCHEDULED`
* set `attempt` to `0`
* set `expires` to `nil`

```elixir
Ecto.Multi.new()
|> MyApp.Job.requeue("requeue_job", failed_job)
|> MyApp.Repo.transaction()
```

[#43](https://github.com/mbuhot/ecto_job/pull/43) - [mbuhot](https://github.com/mbuhot), [seangeo](https://github.com/seangeo) - Fixed issue where too many rows would be locked, causing negative demand in GenStage producer. See [this document](https://github.com/feikesteenbergen/demos/blob/master/bugs/update_from_correlated.adoc) for additional details.

[#41](https://github.com/mbuhot/ecto_job/pull/41) - [mbuhot](https://github.com/mbuhot) - Fixed dialyzer warnings in `JobQueue` modules

[#42](https://github.com/mbuhot/ecto_job/pull/42) - [sneako](https://github.com/sneako) - Improved documentation


[#48](https://github.com/mbuhot/ecto_job/pull/48) - [darksheik](https://github.com/darksheik) - Improved documentation

Thankyou contributors!


# 2.0.0

EctoJob 2.0 adds support for Ecto 3.0.

There should be no breaking changes other than the dependency on `ecto_sql ~> 3.0`.

[#31](https://github.com/mbuhot/ecto_job/pull/31) - [mbuhot](https://github.com/mbuhot) - Timestamp options on job tables can be customized.

[#30](https://github.com/mbuhot/ecto_job/pull/30) - [mbuhot](https://github.com/mbuhot) - Job tables can be declared with custom `schema_prefix`.

[#29](https://github.com/mbuhot/ecto_job/pull/29) - [mbuhot](https://github.com/mbuhot) - EctoJob will always use a `:bigserial` primary key instead of relying on the `ecto` default.


# 1.0.0

[#24](https://github.com/mbuhot/ecto_job/pull/24) - [mbuhot](https://github.com/mbuhot) - EctoJob will work in a polling fashion when `Postgrex.Notifications` is not working reliably.
See https://github.com/elixir-ecto/postgrex/issues/375 for some background.

[#23](https://github.com/mbuhot/ecto_job/pull/23) - [enzoqtvf](https://github.com/enzoqtvf) - Add a configuration option `notifications_listen_timeout` for timeout for call to `Postgrex.Notifications.listen!/3`

[#22](https://github.com/mbuhot/ecto_job/pull/22) - [niku](https://github.com/niku) - Fix code samples in README

# 0.3.0

[#17](https://github.com/mbuhot/ecto_job/pull/17) - [mmartinson](https://github.com/mmartinson) - Make base expiry configurable

Adds configuration options for `execution_timeout` and `reservation_timeout`.

# 0.2.1

[#14](https://github.com/mbuhot/ecto_job/pull/14) - [mbuhot](https://github.com/mbuhot) - Improve configuration flexibility

Configuration can be supplied through the supervisor opts, application config, or fallback to defaults.

[#15](https://github.com/mbuhot/ecto_job/pull/15) - [mbuhot](https://github.com/mbuhot) - Fix dialyzer warnings and improve docs.

# 0.2.0

[#9](https://github.com/mbuhot/ecto_job/pull/9) - [darksheik](https://github.com/darksheik) - Configurable job polling interval

[#11](https://github.com/mbuhot/ecto_job/pull/11) - [darksheik](https://github.com/darksheik) - Configurable logging level

# 0.1.1

[#5](https://github.com/mbuhot/ecto_job/pull/5) - [darksheik](https://github.com/darksheik) - Ensure triggers dropped on job table down migration.

# 0.1

Initial Release to Hex.pm
