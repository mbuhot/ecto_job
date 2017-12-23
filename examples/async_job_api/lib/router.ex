defmodule AsyncJobApi.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/report", to: AsyncJobApi.ReportHandler
end