# EctoJobDemo

The demo application shows EctoJob in action.

## Usage

Run some jobs with ecto_job:

```
mix escript.build && ./ecto_job_demo 1000 ecto_job
```

```
21:53:55.288 [debug] QUERY OK source="jobs" db=0.3ms
UPDATE "jobs" AS j0 SET "attempt" = $1, "state" = $2, "expires" = $3, "updated_at" = $4 WHERE (j0."id" = $5) AND (j0."attempt" = $6) AND (j0."state" = 'RESERVED') AND (j0."expires" >= $7) RETURNING j0."id", j0."state", j0."expires", j0."schedule", j0."attempt", j0."max_attempts", j0."module", j0."function", j0."arguments", j0."inserted_at", j0."updated_at" [1, "IN_PROGRESS", {{2017, 8, 22}, {11, 58, 55, 0}}, {{2017, 8, 22}, {11, 53, 55, 287900}}, 97813, 0, {{2017, 8, 22}, {11, 53, 55, 287900}}]

Hello 1000

21:53:55.288 [debug] QUERY OK db=0.1ms
begin []

21:53:55.289 [debug] QUERY OK db=0.4ms
DELETE FROM "jobs" WHERE "attempt" = $1 AND "id" = $2 [1, 97813]

21:53:55.289 [debug] QUERY OK db=0.2ms
commit []

21:53:55.289 [info]  Elixir.EctoJobDemo[97813] done: 1790 µs
```


Compare with exq:

```
docker run -p 6379:6379 -d redis
mix escript.build && ./ecto_job_demo 1000 exq
```

```
21:41:35.044 [info]  Elixir.EctoJobDemo[96fa8ae3-2d7d-4dc9-9c32-cc451b027c72] start
Hello 964
21:41:35.044 [info]  Elixir.EctoJobDemo[ecf710d8-07d3-4b05-9633-ea72c3f772d8] done: 893µs sec
```

So for a trivial job the overhead of `ecto_job` is about another 1ms added to the execution time of an `exq` job.
