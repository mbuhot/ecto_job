defmodule SimpleDemo.Application do
  @moduledoc """
  The SimpleDemo Application Service.

  The simple_demo system business domain lives in this application.

  Exposes API to clients such as the `SimpleDemoWeb` application
  for use in channels, controllers, and elsewhere.
  """
  use Application


  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(SimpleDemo.Repo, []),
      supervisor(SimpleDemo.JobQueue, [[repo: SimpleDemo.Repo, max_demand: 100]])
    ]

    opts = [strategy: :one_for_one, name: SimpleDemo.Supervisor]

    Supervisor.start_link(children, opts)
 end

end
