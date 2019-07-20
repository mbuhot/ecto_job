# EctoJobPriorityDemo

This demo application shows EctoJob in action with different priorities in the same queue.

## How it works

There are three GenServers adding the same quantity of Ecto Jobs with different priorities after every 5 seconds. The Job with higher priority takes more time to execute than the others to make clear that the priority is respected.

```elixir
  high_priority    = 100 - (0 * 50) = 100 |> Process.sleep()
  regular_priority = 100 - (1 * 50) = 50 |> Process.sleep()
  low_priority     = 100 - (2 * 50) = 0 |> Process.sleep()
```

The default value of priority is `0`. To decrease the priority you must increase its value.

As you will see even the faster jobs are executed later if configured with low priority.

### Setup Postgresql

To start up the docker-compose postgresql service:
```bash
make start_db
```

### Setup Database

To run the project migration:
```bash
make migrate
```

### Running the application

To run the project:
```bash
make run
```
