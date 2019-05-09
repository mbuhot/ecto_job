defmodule EctoJob.EctoJobLive do
  use Phoenix.LiveView
  require EctoJob.Producer
  alias EctoJob.LiveUpdates
  def render(assigns) do
    ~L"""
      <link rel="stylesheet" href="https://unpkg.com/spectre.css/dist/spectre.min.css">
      <h2>Ecto Job Live View</h2>
      <table class='table'>
      <thead>
        <th>ID</th>
        <th>State</th>
        <th>Expires</th>
        <th>Schedule</th>
        <th>Attempt</th>
        <th>Max Attempts</th>
        <th>Params</th>
        <th>Notify</th>
        <th>Inserted At</th>
        <th>Updated At</th>
      </thead>
      <tbody>
      <%= for job <- @jobs do %>
        <tr>
          <td><%= job["id"] %></td>
          <td><%= job["state"] %></td>
          <td><%= job["expires"] %></td>
          <td><%= job["schedule"] %></td>
          <td><%= job["attempt"] %></td>
          <td><%= job["max_attempts"] %></td>
          <td>
          <dl>
            <%= for {key, value} <- job["params"] do %>
            <dd><%= key <> ": " <> value %></dd>
            <% end%>
          <dl>
          </td>
          <td><%= job["notify"] %></td>
          <td><%= job["inserted_at"] %></td>
          <td><%= job["updated_at"] %></td>
        </tr>
      <% end %>
      </tbody>
      </table>
    """
  end

  def mount(_session, socket) do
    if connected?(socket), do: IO.puts "Ecto job live view mounted"
    jobs = LiveUpdates.get_all_jobs(LiveUpdates)
    pubsub = LiveUpdates.get_pubsub_name(LiveUpdates)
    Phoenix.PubSub.subscribe(pubsub, "EctoJob.LiveUpdates", link: true)
    {:ok, assign(socket, jobs: jobs)}
  end

  def handle_info("update", socket) do
    jobs = EctoJob.LiveUpdates.get_all_jobs(EctoJob.LiveUpdates)
    {:noreply, assign(socket, jobs: jobs)}
  end
end
