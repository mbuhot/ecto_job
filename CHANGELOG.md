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
