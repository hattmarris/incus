defmodule Incus.Instances do
  alias Incus.Endpoint
  alias Incus.Websocket
  alias Incus.Log

  @doc """
  GET /1.0/instances

  Returns a list of instances (URLs).

  ## Examples

      iex> Incus.Instances.get()
      {:ok, ["/1.0/instances/a1"]}

      iex> Incus.Instances.get(recursion: 1)
      {:ok, [%{"architecture" => "x86_64", "Status" => "Running", "type" => "container"}]}
  """
  @spec get(list) :: Incus.resp_t()
  def get(opts \\ []) do
    endpoint = %Endpoint{method: "GET", version: "1.0", path: "/instances"}

    params =
      opts
      |> Enum.reduce(%{}, fn
        {:recursion, n}, acc -> Map.put(acc, :recursion, n)
        _, acc -> acc
      end)

    opts
    |> Incus.new()
    |> Req.get(url: endpoint.path, params: params)
    |> Incus.handle(endpoint, opts)
  end

  @doc """
  POST /1.0/instances

  Creates a new instance
  Depending on the source, this can create an instance from an existing
  local image, remote image, existing local instance or snapshot, remote
  migration stream or backup file.

  ## Examples

      iex> Incus.Instances.post(%{
      ...>   name: "alp",
      ...>   type: :container,
      ...>   source: %{
      ...>     alias: "alpine/3.21",
      ...>     type: :image,
      ...>     mode: "pull",
      ...>     protocol: "simplestreams",
      ...>     server: "https://images.linuxcontainers.org",
      ...>     architecture: :armv7l
      ...>   }
      ...> })
      {:ok, %{"class" => "task", "description" => "Creating instance" }}
  """
  @spec post(map, list) :: Incus.resp_t()
  def post(body, opts \\ []) do
    endpoint = %Endpoint{method: "POST", version: "1.0", path: "/instances"}

    opts
    |> Incus.new()
    |> Req.post(url: endpoint.path, body: Jason.encode!(body))
    |> Incus.handle(endpoint, opts)
  end

  @doc """
  POST /1.0/instances/{name}/exec

  Executes a command inside an instance.

  The returned operation metadata will contain either 2 or 4 websockets.
  In non-interactive mode, you'll get one websocket for each of stdin, stdout and stderr.
  In interactive mode, a single bi-directional websocket is used for stdin and stdout/stderr.

  An additional "control" socket is always added on top which can be used for out of band communications.
  This allows sending signals and window sizing information through.
  """
  def exec(name, body, opts \\ []) do
    endpoint = %Endpoint{method: "POST", version: "1.0", path: "/instances/#{name}/exec"}

    {main, control} =
      case opts
           |> Incus.new()
           |> Req.post(url: endpoint.path, body: Jason.encode!(body))
           |> Incus.handle(endpoint, opts) do
        {:ok,
         %{
           "id" => id,
           "metadata" => %{
             "fds" => %{"0" => main, "control" => control}
           }
         }} ->
          {Websocket.url(id, main), Websocket.url(id, control)}
      end

    timeout = Keyword.get(opts, :timeout, 60000)

    ctrl_task =
      Task.async(fn ->
        Websocket.start(control, :control, self())
        listen(timeout)
      end)

    main_task =
      Task.async(fn ->
        Websocket.start(main, :main, self())
        listen(timeout)
      end)

    ctrl_buff =
      case Task.yield(ctrl_task, timeout) || Task.shutdown(ctrl_task, :brutal_kill) do
        {:ok, {:ok, buffer}} -> buffer
        nil -> :error
      end

    main_buff =
      case Task.yield(main_task, timeout) || Task.shutdown(main_task, :brutal_kill) do
        {:ok, {:ok, buffer}} -> buffer
        nil -> :error
      end

    {:ok, ctrl_buff, main_buff}
  end

  def listen(timeout) do
    receive do
      {:data, data} ->
        data
        |> String.split("\n")
        |> Enum.map(fn
          "" -> nil
          "" <> str -> Log.info(str)
          other -> Log.error(other)
        end)

        listen(timeout)

      {:connected, _conn} ->
        listen(timeout)

      {:disconnected, buffer} ->
        {:ok, buffer}

      other ->
        Log.debug("Unexpected message received #{inspect(other)}")
        {:error, other}
    after
      timeout ->
        Log.error("Longer than #{timeout} with no message from Incus.Websocket")
        {:error, :timeout}
    end
  end

  @doc """
  PUT /1.0/instances/{name}/state

  Changes the running state of the instance.

  ## Examples

      iex> Incus.Instances.put_state(:runner, %{
        action: "start",
        timeout: 0,
        force: false,
        stateful: false
      })
      {:ok, %{ "class" => "task", "description" => "Starting instance" }}
  """
  @spec put_state(atom | String.t(), map, list) :: Incus.resp_t()
  def put_state(name, body, opts \\ []) do
    endpoint = %Endpoint{method: "PUT", version: "1.0", path: "/instances/#{name}/state"}

    opts
    |> Incus.new()
    |> Req.put(url: endpoint.path, body: Jason.encode!(body))
    |> Incus.handle(endpoint, opts)
  end

  @doc """
  DELETE /1.0/instances/{name}

  Deletes a specific instance.

  This also deletes anything owned by the instance such as snapshots and backups.

  ## Examples

      iex> Incus.Instances.delete(:runner)
      {:ok, %{ "class" => "task", "description" => "Deleting instance" }}
  """
  @spec delete(atom | String.t(), list) :: Incus.resp_t()
  def delete(name, opts \\ []) do
    endpoint = %Endpoint{method: "DELETE", version: "1.0", path: "/instances/#{name}"}

    opts
    |> Incus.new()
    |> Req.delete(url: endpoint.path)
    |> Incus.handle(endpoint, opts)
  end
end
