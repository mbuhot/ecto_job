defmodule EctoJob.Test.Repo do
  adapter = Application.compile_env!(:ecto_job, __MODULE__)[:adapter]
  use Ecto.Repo, otp_app: :ecto_job, adapter: adapter
end
