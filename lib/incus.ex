defmodule Incus do
  alias Req.Response

  defmodule Endpoint do
    @enforce_keys [:method, :version, :path]
    @type t :: %__MODULE__{method: String.t(), version: String.t(), path: Path.t()}
    defstruct method: nil, version: nil, path: nil
  end

  alias Incus.Endpoint
  alias Incus.Instances
  alias Incus.Log
  alias Incus.Operations

  def new(opts \\ []) do
    case Keyword.get(opts, :server, :local) do
      :images ->
        [
          base_url: "https://images.linuxcontainers.org"
        ]

      :remote ->
        [
          base_url: "https://127.0.0.1:8443/1.0",
          connect_options: [
            transport_opts: [
              verify: :verify_none,
              certfile: System.user_home() <> "/.config/incus/client.crt",
              keyfile: System.user_home() <> "/.config/incus/client.key"
            ]
          ]
        ]

      :local ->
        [
          base_url: "http://localhost/1.0",
          unix_socket: "/var/lib/incus/unix.socket"
        ]
    end
    |> Req.new()
  end

  @type resp_t :: {:ok, Req.Response.t() | map} | {:error, Req.Response.t() | String.t()}
  @spec handle(tuple, Endpoint.t(), list) :: resp_t
  def handle(resp_tuple, %Endpoint{} = endpoint, opts \\ []) do
    resp? = Keyword.get(opts, :response, false)

    case resp_tuple do
      {:ok, %Response{status: status, body: body} = response} when status in 200..399 ->
        output = if resp?, do: response, else: body["metadata"]
        {:ok, output}

      {:ok, %Req.Response{status: status, body: body} = response} when status in 400..599 ->
        error = body["error"]
        Log.error(error)
        output = if resp?, do: response, else: error
        {:error, output}

      {:error, _e} = error ->
        Log.error("Error Req could not #{to_str(endpoint)}")
        {:error, error}
    end
  end

  def short_print(fingerprint) do
    fingerprint |> String.slice(0, 12)
  end

  defp ver_path(%Endpoint{} = endpoint) do
    Path.join(["/", endpoint.version, endpoint.path])
  end

  defp to_str(%Endpoint{method: method} = endpoint) do
    "#{method} #{ver_path(endpoint)}"
  end

  @doc """
  Create and start instances from images

  ## Examples

      iex> Incus.launch(:alp, images: "alpine/3.21", type: :container, arch: :armv7l)
      :ok
      iex> Incus.launch(:alp, alias: "x86_64-alpine-linux-musl", type: :container, arch: :x86_64)
      :ok
  """
  @spec launch(atom | String.t(), list) :: :ok | :error
  def launch(name, opts \\ []) do
    name = to_string(name)

    source =
      opts
      |> Enum.reduce(%{}, fn opt, acc ->
        case opt do
          {:images, a} ->
            acc
            |> Map.merge(%{
              server: "https://images.linuxcontainers.org",
              mode: "pull",
              alias: a,
              protocol: "simplestreams"
            })

          {:alias, a} ->
            Map.merge(acc, %{alias: a})

          {:fingerprint, f} ->
            Map.merge(acc, %{fingerprint: f})

          {:arch, arch} ->
            Map.merge(acc, %{architecture: arch})

          _ ->
            acc
        end
      end)
      |> Map.put(:type, :image)

    {:ok, %{"id" => id}} =
      %{
        name: name,
        source: source,
        type: Keyword.get(opts, :type, :container)
      }
      |> Log.debug()
      |> Instances.post(opts)

    Log.info("Creating instance")

    case await_create(id, Keyword.take(opts, [:timeout])) do
      :ok -> start(name)
      :error -> :error
    end
  end

  def start(name) do
    {:ok, %{"id" => id}} =
      Instances.put_state(name, %{
        action: "start",
        timeout: 0,
        force: false,
        stateful: false
      })

    case Operations.wait(id) do
      {:ok, %Req.Response{body: %{"status_code" => 200}}} ->
        Log.info("Instance started (#{name})")
        :ok

      {:ok, %Req.Response{body: %{"error" => error}}} ->
        Log.error("Error starting instance: #{error}")
        :error
    end
  end

  def stop(name) do
    {:ok, %{"id" => id}} =
      Instances.put_state(name, %{
        action: "stop",
        timeout: -1,
        force: false,
        stateful: false
      })

    case Operations.wait(id) do
      {:ok, %Req.Response{body: %{"status_code" => 200}}} ->
        Log.info("Instance stopped (#{name})")
        :ok

      {:ok, %Req.Response{body: %{"error" => error}}} ->
        Log.error("Error stopping instance: #{error}")
        :error
    end
  end

  def delete(name) do
    {:ok, %{"id" => id}} = Instances.delete(name)

    case Operations.wait(id) do
      {:ok, %Req.Response{body: %{"status_code" => 200}}} ->
        Log.info("Instance deleted #{name}")
        :ok

      {:ok, %Req.Response{body: %{"error" => error}}} ->
        Log.error("Error deleting instance: #{error}")
        :error
    end
  end

  defp await_create(id, opts) do
    case Operations.wait(id, opts) do
      {:ok, %Req.Response{body: %{"status_code" => 200}}} ->
        Log.info("Instance created")
        :ok

      {:ok, %Req.Response{body: %{"error" => "context deadline exceeded"}}} ->
        Log.info("Timeout exceeded, instance may still be created")
        :ok

      {:ok, %Req.Response{body: %{"error" => error}}} ->
        Log.error("Instance creation error: #{error}")
        :error
    end
  end
end
