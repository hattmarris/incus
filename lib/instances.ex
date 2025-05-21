defmodule Incus.Instances do
  alias Incus.Endpoint

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
