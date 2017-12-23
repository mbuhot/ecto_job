defmodule AsyncJobApi.Repo do
  use Ecto.Repo, otp_app: :async_job_api

  def notify(topic, payload) do
    query("SELECT pg_notify($1, $2)", [topic, payload])
  end
end