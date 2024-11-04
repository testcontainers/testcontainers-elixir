# NOTE: This file is auto generated by OpenAPI Generator 7.0.1 (https://openapi-generator.tech).
# Do not edit this file manually.

defmodule DockerEngineAPI.Api.Container do
  @moduledoc """
  API calls for all endpoints tagged `Container`.
  """

  alias DockerEngineAPI.Connection
  import DockerEngineAPI.RequestBuilder

  @doc """
  Get an archive of a filesystem resource in a container
  Get a tar archive of a resource in the filesystem of container id.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `path` (String.t): Resource in the container’s filesystem to archive.
  - `opts` (keyword): Optional parameters

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_archive(Tesla.Env.client, String.t, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_archive(connection, id, path, _opts \\ []) do
    request =
      %{}
      |> method(:get)
      |> url("/containers/#{id}/archive")
      |> add_param(:query, :path, path)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, false},
      {400, DockerEngineAPI.Model.ErrorResponse},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Get information about files in a container
  A response header `X-Docker-Container-Path-Stat` is returned, containing a base64 - encoded JSON object with some filesystem header information about the path.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `path` (String.t): Resource in the container’s filesystem to archive.
  - `opts` (keyword): Optional parameters

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_archive_info(Tesla.Env.client, String.t, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_archive_info(connection, id, path, _opts \\ []) do
    request =
      %{}
      |> method(:head)
      |> url("/containers/#{id}/archive")
      |> add_param(:query, :path, path)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, false},
      {400, DockerEngineAPI.Model.ErrorResponse},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Attach to a container
  Attach to a container to read its output or send it input. You can attach to the same container multiple times and you can reattach to containers that have been detached.  Either the `stream` or `logs` parameter must be `true` for this endpoint to do anything.  See the [documentation for the `docker attach` command](https://docs.docker.com/engine/reference/commandline/attach/) for more details.  ### Hijacking  This endpoint hijacks the HTTP connection to transport `stdin`, `stdout`, and `stderr` on the same socket.  This is the response from the daemon for an attach request:  ``` HTTP/1.1 200 OK Content-Type: application/vnd.docker.raw-stream  [STREAM] ```  After the headers and two new lines, the TCP connection can now be used for raw, bidirectional communication between the client and server.  To hint potential proxies about connection hijacking, the Docker client can also optionally send connection upgrade headers.  For example, the client sends this request to upgrade the connection:  ``` POST /containers/16253994b7c4/attach?stream=1&stdout=1 HTTP/1.1 Upgrade: tcp Connection: Upgrade ```  The Docker daemon will respond with a `101 UPGRADED` response, and will similarly follow with the raw stream:  ``` HTTP/1.1 101 UPGRADED Content-Type: application/vnd.docker.raw-stream Connection: Upgrade Upgrade: tcp  [STREAM] ```  ### Stream format  When the TTY setting is disabled in [`POST /containers/create`](#operation/ContainerCreate), the HTTP Content-Type header is set to application/vnd.docker.multiplexed-stream and the stream over the hijacked connected is multiplexed to separate out `stdout` and `stderr`. The stream consists of a series of frames, each containing a header and a payload.  The header contains the information which the stream writes (`stdout` or `stderr`). It also contains the size of the associated frame encoded in the last four bytes (`uint32`).  It is encoded on the first eight bytes like this:  ```go header := [8]byte{STREAM_TYPE, 0, 0, 0, SIZE1, SIZE2, SIZE3, SIZE4} ```  `STREAM_TYPE` can be:  - 0: `stdin` (is written on `stdout`) - 1: `stdout` - 2: `stderr`  `SIZE1, SIZE2, SIZE3, SIZE4` are the four bytes of the `uint32` size encoded as big endian.  Following the header is the payload, which is the specified number of bytes of `STREAM_TYPE`.  The simplest way to implement this protocol is the following:  1. Read 8 bytes. 2. Choose `stdout` or `stderr` depending on the first byte. 3. Extract the frame size from the last four bytes. 4. Read the extracted size and output it on the correct output. 5. Goto 1.  ### Stream format when using a TTY  When the TTY setting is enabled in [`POST /containers/create`](#operation/ContainerCreate), the stream is not multiplexed. The data exchanged over the hijacked connection is simply the raw data from the process PTY and client's `stdin`.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters
    - `:detachKeys` (String.t): Override the key sequence for detaching a container.Format is a single character `[a-Z]` or `ctrl-<value>` where `<value>` is one of: `a-z`, `@`, `^`, `[`, `,` or `_`.
    - `:logs` (boolean()): Replay previous logs from the container.  This is useful for attaching to a container that has started and you want to output everything since the container started.  If `stream` is also enabled, once all the previous output has been returned, it will seamlessly transition into streaming current output.
    - `:stream` (boolean()): Stream attached streams from the time the request was made onwards.
    - `:stdin` (boolean()): Attach to `stdin`
    - `:stdout` (boolean()): Attach to `stdout`
    - `:stderr` (boolean()): Attach to `stderr`

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_attach(Tesla.Env.client, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_attach(connection, id, opts \\ []) do
    optional_params = %{
      :detachKeys => :query,
      :logs => :query,
      :stream => :query,
      :stdin => :query,
      :stdout => :query,
      :stderr => :query
    }

    request =
      %{}
      |> method(:post)
      |> url("/containers/#{id}/attach")
      |> add_optional_params(optional_params, opts)
      |> ensure_body()
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {101, false},
      {200, false},
      {400, DockerEngineAPI.Model.ErrorResponse},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Attach to a container via a websocket

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters
    - `:detachKeys` (String.t): Override the key sequence for detaching a container.Format is a single character `[a-Z]` or `ctrl-<value>` where `<value>` is one of: `a-z`, `@`, `^`, `[`, `,`, or `_`.
    - `:logs` (boolean()): Return logs
    - `:stream` (boolean()): Return stream
    - `:stdin` (boolean()): Attach to `stdin`
    - `:stdout` (boolean()): Attach to `stdout`
    - `:stderr` (boolean()): Attach to `stderr`

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_attach_websocket(Tesla.Env.client, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_attach_websocket(connection, id, opts \\ []) do
    optional_params = %{
      :detachKeys => :query,
      :logs => :query,
      :stream => :query,
      :stdin => :query,
      :stdout => :query,
      :stderr => :query
    }

    request =
      %{}
      |> method(:get)
      |> url("/containers/#{id}/attach/ws")
      |> add_optional_params(optional_params, opts)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {101, false},
      {200, false},
      {400, DockerEngineAPI.Model.ErrorResponse},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Get changes on a container’s filesystem
  Returns which files in a container's filesystem have been added, deleted, or modified. The `Kind` of modification can be one of:  - `0`: Modified (\"C\") - `1`: Added (\"A\") - `2`: Deleted (\"D\")

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters

  ### Returns

  - `{:ok, [%FilesystemChange{}, ...]}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_changes(Tesla.Env.client, String.t, keyword()) :: {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:ok, list(DockerEngineAPI.Model.FilesystemChange.t)} | {:error, Tesla.Env.t}
  def container_changes(connection, id, _opts \\ []) do
    request =
      %{}
      |> method(:get)
      |> url("/containers/#{id}/changes")
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, DockerEngineAPI.Model.FilesystemChange},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Create a container

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `body` (ContainerCreateRequest): Container to create
  - `opts` (keyword): Optional parameters
    - `:name` (String.t): Assign the specified name to the container. Must match `/?[a-zA-Z0-9][a-zA-Z0-9_.-]+`.
    - `:platform` (String.t): Platform in the format `os[/arch[/variant]]` used for image lookup.  When specified, the daemon checks if the requested image is present in the local image cache with the given OS and Architecture, and otherwise returns a `404` status.  If the option is not set, the host's native OS and Architecture are used to look up the image in the image cache. However, if no platform is passed and the given image does exist in the local image cache, but its OS or architecture does not match, the container is created with the available image, and a warning is added to the `Warnings` field in the response, for example;      WARNING: The requested image's platform (linux/arm64/v8) does not              match the detected host platform (linux/amd64) and no              specific platform was requested

  ### Returns

  - `{:ok, DockerEngineAPI.Model.ContainerCreateResponse.t}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_create(Tesla.Env.client, DockerEngineAPI.Model.ContainerCreateRequest.t, keyword()) :: {:ok, DockerEngineAPI.Model.ContainerCreateResponse.t} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_create(connection, body, opts \\ []) do
    optional_params = %{
      :name => :query,
      :platform => :query
    }

    request =
      %{}
      |> method(:post)
      |> url("/containers/create")
      |> add_param(:body, :body, body)
      |> add_optional_params(optional_params, opts)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {201, DockerEngineAPI.Model.ContainerCreateResponse},
      {400, DockerEngineAPI.Model.ErrorResponse},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {409, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Remove a container

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters
    - `:v` (boolean()): Remove anonymous volumes associated with the container.
    - `:force` (boolean()): If the container is running, kill it before removing it.
    - `:link` (boolean()): Remove the specified link associated with the container.

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_delete(Tesla.Env.client, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_delete(connection, id, opts \\ []) do
    optional_params = %{
      :v => :query,
      :force => :query,
      :link => :query
    }

    request =
      %{}
      |> method(:delete)
      |> url("/containers/#{id}")
      |> add_optional_params(optional_params, opts)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {204, false},
      {400, DockerEngineAPI.Model.ErrorResponse},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {409, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Export a container
  Export the contents of a container as a tarball.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_export(Tesla.Env.client, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_export(connection, id, _opts \\ []) do
    request =
      %{}
      |> method(:get)
      |> url("/containers/#{id}/export")
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, false},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Inspect a container
  Return low-level information about a container.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters
    - `:size` (boolean()): Return the size of container as fields `SizeRw` and `SizeRootFs`

  ### Returns

  - `{:ok, DockerEngineAPI.Model.ContainerInspectResponse.t}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_inspect(Tesla.Env.client, String.t, keyword()) :: {:ok, DockerEngineAPI.Model.ContainerInspectResponse.t} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_inspect(connection, id, opts \\ []) do
    optional_params = %{
      :size => :query
    }

    request =
      %{}
      |> method(:get)
      |> url("/containers/#{id}/json")
      |> add_optional_params(optional_params, opts)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, DockerEngineAPI.Model.ContainerInspectResponse},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Kill a container
  Send a POSIX signal to a container, defaulting to killing to the container.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters
    - `:signal` (String.t): Signal to send to the container as an integer or string (e.g. `SIGINT`).

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_kill(Tesla.Env.client, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_kill(connection, id, opts \\ []) do
    optional_params = %{
      :signal => :query
    }

    request =
      %{}
      |> method(:post)
      |> url("/containers/#{id}/kill")
      |> add_optional_params(optional_params, opts)
      |> ensure_body()
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {204, false},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {409, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  List containers
  Returns a list of containers. For details on the format, see the [inspect endpoint](#operation/ContainerInspect).  Note that it uses a different, smaller representation of a container than inspecting a single container. For example, the list of linked containers is not propagated .

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `opts` (keyword): Optional parameters
    - `:all` (boolean()): Return all containers. By default, only running containers are shown.
    - `:limit` (integer()): Return this number of most recently created containers, including non-running ones.
    - `:size` (boolean()): Return the size of container as fields `SizeRw` and `SizeRootFs`.
    - `:filters` (String.t): Filters to process on the container list, encoded as JSON (a `map[string][]string`). For example, `{\"status\": [\"paused\"]}` will only return paused containers.  Available filters:  - `ancestor`=(`<image-name>[:<tag>]`, `<image id>`, or `<image@digest>`) - `before`=(`<container id>` or `<container name>`) - `expose`=(`<port>[/<proto>]`|`<startport-endport>/[<proto>]`) - `exited=<int>` containers with exit code of `<int>` - `health`=(`starting`|`healthy`|`unhealthy`|`none`) - `id=<ID>` a container's ID - `isolation=`(`default`|`process`|`hyperv`) (Windows daemon only) - `is-task=`(`true`|`false`) - `label=key` or `label=\"key=value\"` of a container label - `name=<name>` a container's name - `network`=(`<network id>` or `<network name>`) - `publish`=(`<port>[/<proto>]`|`<startport-endport>/[<proto>]`) - `since`=(`<container id>` or `<container name>`) - `status=`(`created`|`restarting`|`running`|`removing`|`paused`|`exited`|`dead`) - `volume`=(`<volume name>` or `<mount point destination>`)

  ### Returns

  - `{:ok, [%ContainerSummary{}, ...]}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_list(Tesla.Env.client, keyword()) :: {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:ok, list(DockerEngineAPI.Model.ContainerSummary.t)} | {:error, Tesla.Env.t}
  def container_list(connection, opts \\ []) do
    optional_params = %{
      :all => :query,
      :limit => :query,
      :size => :query,
      :filters => :query
    }

    request =
      %{}
      |> method(:get)
      |> url("/containers/json")
      |> add_optional_params(optional_params, opts)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, DockerEngineAPI.Model.ContainerSummary},
      {400, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Get container logs
  Get `stdout` and `stderr` logs from a container.  Note: This endpoint works only for containers with the `json-file` or `journald` logging driver.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters
    - `:follow` (boolean()): Keep connection after returning logs.
    - `:stdout` (boolean()): Return logs from `stdout`
    - `:stderr` (boolean()): Return logs from `stderr`
    - `:since` (integer()): Only return logs since this time, as a UNIX timestamp
    - `:until` (integer()): Only return logs before this time, as a UNIX timestamp
    - `:timestamps` (boolean()): Add timestamps to every log line
    - `:tail` (String.t): Only return this number of log lines from the end of the logs. Specify as an integer or `all` to output all log lines.
  """
  @spec container_logs(Tesla.Env.client, String.t, keyword()) :: {:ok, DockerEngineAPI.Model.ErrorResponse.t | Tesla.Env.t} | {:error, Tesla.Env.t}
  def container_logs(connection, id, opts \\ []) do
    optional_params = %{
      :follow => :query,
      :stdout => :query,
      :stderr => :query,
      :since => :query,
      :until => :query,
      :timestamps => :query,
      :tail => :query
    }

    request =
      %{}
      |> method(:get)
      |> url("/containers/#{id}/logs")
      |> add_optional_params(optional_params, opts)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, false},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Pause a container
  Use the freezer cgroup to suspend all processes in a container.  Traditionally, when suspending a process the `SIGSTOP` signal is used, which is observable by the process being suspended. With the freezer cgroup the process is unaware, and unable to capture, that it is being suspended, and subsequently resumed.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_pause(Tesla.Env.client, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_pause(connection, id, _opts \\ []) do
    request =
      %{}
      |> method(:post)
      |> url("/containers/#{id}/pause")
      |> ensure_body()
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {204, false},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Delete stopped containers

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `opts` (keyword): Optional parameters
    - `:filters` (String.t): Filters to process on the prune list, encoded as JSON (a `map[string][]string`).  Available filters: - `until=<timestamp>` Prune containers created before this timestamp. The `<timestamp>` can be Unix timestamps, date formatted timestamps, or Go duration strings (e.g. `10m`, `1h30m`) computed relative to the daemon machine’s time. - `label` (`label=<key>`, `label=<key>=<value>`, `label!=<key>`, or `label!=<key>=<value>`) Prune containers with (or without, in case `label!=...` is used) the specified labels.

  ### Returns

  - `{:ok, DockerEngineAPI.Model.ContainerPruneResponse.t}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_prune(Tesla.Env.client, keyword()) :: {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:ok, DockerEngineAPI.Model.ContainerPruneResponse.t} | {:error, Tesla.Env.t}
  def container_prune(connection, opts \\ []) do
    optional_params = %{
      :filters => :query
    }

    request =
      %{}
      |> method(:post)
      |> url("/containers/prune")
      |> add_optional_params(optional_params, opts)
      |> ensure_body()
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, DockerEngineAPI.Model.ContainerPruneResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Rename a container

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `name` (String.t): New name for the container
  - `opts` (keyword): Optional parameters

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_rename(Tesla.Env.client, String.t, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_rename(connection, id, name, _opts \\ []) do
    request =
      %{}
      |> method(:post)
      |> url("/containers/#{id}/rename")
      |> add_param(:query, :name, name)
      |> ensure_body()
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {204, false},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {409, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Resize a container TTY
  Resize the TTY for a container.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters
    - `:h` (integer()): Height of the TTY session in characters
    - `:w` (integer()): Width of the TTY session in characters

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_resize(Tesla.Env.client, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_resize(connection, id, opts \\ []) do
    optional_params = %{
      :h => :query,
      :w => :query
    }

    request =
      %{}
      |> method(:post)
      |> url("/containers/#{id}/resize")
      |> add_optional_params(optional_params, opts)
      |> ensure_body()
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, false},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Restart a container

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters
    - `:signal` (String.t): Signal to send to the container as an integer or string (e.g. `SIGINT`).
    - `:t` (integer()): Number of seconds to wait before killing the container

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_restart(Tesla.Env.client, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_restart(connection, id, opts \\ []) do
    optional_params = %{
      :signal => :query,
      :t => :query
    }

    request =
      %{}
      |> method(:post)
      |> url("/containers/#{id}/restart")
      |> add_optional_params(optional_params, opts)
      |> ensure_body()
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {204, false},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Start a container

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters
    - `:detachKeys` (String.t): Override the key sequence for detaching a container. Format is a single character `[a-Z]` or `ctrl-<value>` where `<value>` is one of: `a-z`, `@`, `^`, `[`, `,` or `_`.

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_start(Tesla.Env.client, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_start(connection, id, opts \\ []) do
    optional_params = %{
      :detachKeys => :query
    }

    request =
      %{}
      |> method(:post)
      |> url("/containers/#{id}/start")
      |> add_optional_params(optional_params, opts)
      |> ensure_body()
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {204, false},
      {304, false},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Get container stats based on resource usage
  This endpoint returns a live stream of a container’s resource usage statistics.  The `precpu_stats` is the CPU statistic of the *previous* read, and is used to calculate the CPU usage percentage. It is not an exact copy of the `cpu_stats` field.  If either `precpu_stats.online_cpus` or `cpu_stats.online_cpus` is nil then for compatibility with older daemons the length of the corresponding `cpu_usage.percpu_usage` array should be used.  On a cgroup v2 host, the following fields are not set * `blkio_stats`: all fields other than `io_service_bytes_recursive` * `cpu_stats`: `cpu_usage.percpu_usage` * `memory_stats`: `max_usage` and `failcnt` Also, `memory_stats.stats` fields are incompatible with cgroup v1.  To calculate the values shown by the `stats` command of the docker cli tool the following formulas can be used: * used_memory = `memory_stats.usage - memory_stats.stats.cache` * available_memory = `memory_stats.limit` * Memory usage % = `(used_memory / available_memory) * 100.0` * cpu_delta = `cpu_stats.cpu_usage.total_usage - precpu_stats.cpu_usage.total_usage` * system_cpu_delta = `cpu_stats.system_cpu_usage - precpu_stats.system_cpu_usage` * number_cpus = `lenght(cpu_stats.cpu_usage.percpu_usage)` or `cpu_stats.online_cpus` * CPU usage % = `(cpu_delta / system_cpu_delta) * number_cpus * 100.0`

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters
    - `:stream` (boolean()): Stream the output. If false, the stats will be output once and then it will disconnect.
    - `:"one-shot"` (boolean()): Only get a single stat instead of waiting for 2 cycles. Must be used with `stream=false`.

  ### Returns

  - `{:ok, map()}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_stats(Tesla.Env.client, String.t, keyword()) :: {:ok, Map.t} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_stats(connection, id, opts \\ []) do
    optional_params = %{
      :stream => :query,
      :"one-shot" => :query
    }

    request =
      %{}
      |> method(:get)
      |> url("/containers/#{id}/stats")
      |> add_optional_params(optional_params, opts)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, %{}},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Stop a container

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters
    - `:signal` (String.t): Signal to send to the container as an integer or string (e.g. `SIGINT`).
    - `:t` (integer()): Number of seconds to wait before killing the container

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_stop(Tesla.Env.client, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_stop(connection, id, opts \\ []) do
    optional_params = %{
      :signal => :query,
      :t => :query
    }

    request =
      %{}
      |> method(:post)
      |> url("/containers/#{id}/stop")
      |> add_optional_params(optional_params, opts)
      |> ensure_body()
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {204, false},
      {304, false},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  List processes running inside a container
  On Unix systems, this is done by running the `ps` command. This endpoint is not supported on Windows.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters
    - `:ps_args` (String.t): The arguments to pass to `ps`. For example, `aux`

  ### Returns

  - `{:ok, DockerEngineAPI.Model.ContainerTopResponse.t}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_top(Tesla.Env.client, String.t, keyword()) :: {:ok, DockerEngineAPI.Model.ContainerTopResponse.t} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_top(connection, id, opts \\ []) do
    optional_params = %{
      :ps_args => :query
    }

    request =
      %{}
      |> method(:get)
      |> url("/containers/#{id}/top")
      |> add_optional_params(optional_params, opts)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, DockerEngineAPI.Model.ContainerTopResponse},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Unpause a container
  Resume a container which has been paused.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_unpause(Tesla.Env.client, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_unpause(connection, id, _opts \\ []) do
    request =
      %{}
      |> method(:post)
      |> url("/containers/#{id}/unpause")
      |> ensure_body()
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {204, false},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Update a container
  Change various configuration options of a container without having to recreate it.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `update` (ContainerUpdateRequest):
  - `opts` (keyword): Optional parameters

  ### Returns

  - `{:ok, DockerEngineAPI.Model.ContainerUpdateResponse.t}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_update(Tesla.Env.client, String.t, DockerEngineAPI.Model.ContainerUpdateRequest.t, keyword()) :: {:ok, DockerEngineAPI.Model.ContainerUpdateResponse.t} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_update(connection, id, update, _opts \\ []) do
    request =
      %{}
      |> method(:post)
      |> url("/containers/#{id}/update")
      |> add_param(:body, :body, update)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, DockerEngineAPI.Model.ContainerUpdateResponse},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Wait for a container
  Block until a container stops, then returns the exit code.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters
    - `:condition` (String.t): Wait until a container state reaches the given condition.  Defaults to `not-running` if omitted or empty.

  ### Returns

  - `{:ok, DockerEngineAPI.Model.ContainerWaitResponse.t}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_wait(Tesla.Env.client, String.t, keyword()) :: {:ok, DockerEngineAPI.Model.ContainerWaitResponse.t} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_wait(connection, id, opts \\ []) do
    optional_params = %{
      :condition => :query
    }

    request =
      %{}
      |> method(:post)
      |> url("/containers/#{id}/wait")
      |> add_optional_params(optional_params, opts)
      |> ensure_body()
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, DockerEngineAPI.Model.ContainerWaitResponse},
      {400, DockerEngineAPI.Model.ErrorResponse},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Extract an archive of files or folders to a directory in a container
  Upload a tar archive to be extracted to a path in the filesystem of container id. `path` parameter is asserted to be a directory. If it exists as a file, 400 error will be returned with message \"not a directory\".

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `path` (String.t): Path to a directory in the container to extract the archive’s contents into.
  - `input_stream` (String.t): The input stream must be a tar archive compressed with one of the following algorithms: `identity` (no compression), `gzip`, `bzip2`, or `xz`.
  - `opts` (keyword): Optional parameters
    - `:noOverwriteDirNonDir` (String.t): If `1`, `true`, or `True` then it will be an error if unpacking the given content would cause an existing directory to be replaced with a non-directory and vice versa.
    - `:copyUIDGID` (String.t): If `1`, `true`, then it will copy UID/GID maps to the dest file or dir

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec put_container_archive(Tesla.Env.client, String.t, String.t, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def put_container_archive(connection, id, path, input_stream, opts \\ []) do
    optional_params = %{
      :noOverwriteDirNonDir => :query,
      :copyUIDGID => :query
    }

    request =
      %{}
      |> method(:put)
      |> url("/containers/#{id}/archive")
      |> add_param(:query, :path, path)
      |> add_param(:body, :body, input_stream)
      |> add_optional_params(optional_params, opts)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, false},
      {400, DockerEngineAPI.Model.ErrorResponse},
      {403, DockerEngineAPI.Model.ErrorResponse},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end
end
