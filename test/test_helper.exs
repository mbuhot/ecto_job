ExUnit.start()

EctoJob.Test.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(EctoJob.Test.Repo, :manual)
