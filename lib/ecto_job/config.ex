defmodule EctoJob.Config do
  @moduledoc """
  EctoJob Configuration struct.

  Configuration may be provided directly to your JobQueue supervisor:

      supervisor(MyApp.JobQueue, [[repo: MyApp.Repo, max_demand: 100, log_level: :debug]])

  Or if the configuration should be environment-specific, use Mix config:

      config :ecto_job,
        repo: MyApp.Repo,
        max_demand: 100,
        log_level: :debug

  Otherwise default values will be used.

  Configurable values:

    - `repo`: (Required) The `Ecto.Repo` module in your application to use for accessing the `JobQueue`
    - `max_demand`: (Default `100`) The number of concurrent worker processes to use, see `ConsumerSupervisor` for more details
    - `log`: (Default `true`) Enables logging using the standard Elixir `Logger` module
    - `log_level`: (Default `:info`) The level used to log messages, see [Logger](https://hexdocs.pm/logger/Logger.html#module-levels)
    - `poll_interval`: (Default `60_000`) Time in milliseconds between polling the `JobQueue` for scheduled jobs or jobs due to be retried
    - `base_expiry_seconds`: (Default `300`) Time in seconds where a `RESERVED` or `IN_PROGRESS` job state is held before subsequent polls return a job to the `AVAILABLE` state for retry. The time will double for every retry until `max_attemps` is reached for a given job.
  """

  alias __MODULE__

  defstruct repo: nil,
            schema: nil,
            max_demand: 100,
            log: true,
            log_level: :info,
            poll_interval: 60_000,
            base_expiry_seconds: 300

  @type t :: %Config{}

  @doc """
  Constructs a new `Config` from params, falling back to Application environment then to default values.

  ## Example

      iex> EctoJob.Config.new(repo: MyApp.Repo, log: false)
      %EctoJob.Config{
        repo: MyApp.Repo,
        max_demand: 100,
        log: false,
        log_level: :info,
        poll_interval: 60_000,
        base_expiry_seconds: 300
      }
  """
  @spec new(Keyword.t()) :: Config.t()
  def new(params \\ []) when is_list(params) do
    defaults = Map.from_struct(%Config{})

    Enum.reduce(defaults, %Config{}, fn {key, default}, config ->
      default = Application.get_env(:ecto_job, key, default)
      value = Keyword.get(params, key, default)
      Map.put(config, key, value)
    end)
  end
end
