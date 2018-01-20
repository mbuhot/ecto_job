# AsyncJobApi

This demo application shows how to listen for job completion from a web handler, and respond using server-sent-events.

# Usage

Build and run the application:

```
mix deps.get
mix ecto.create
mix ecto.migrate
mix run --no-halt
```

Send the application a request:

```
curl -v localhost:9876/report
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Connected to localhost (127.0.0.1) port 9876 (#0)
> GET /report HTTP/1.1
> Host: localhost:9876
> User-Agent: curl/7.54.0
> Accept: */*
>
< HTTP/1.1 200 OK
< transfer-encoding: chunked
< server: Cowboy
< date: Fri, 19 Jan 2018 23:03:35 GMT
< cache-control: max-age=0, private, must-revalidate
< content-type: text/event-stream; charset=utf-8
<

```

The initial `200` response is sent immediately, while the job will be processed asynchronously, pausing for 10 seconds to simulate a long task, responding with:

```
event: "message"

data: {"message": "igmboshnthimkrgforulvlydiwppzykt completed!!!"}
```
