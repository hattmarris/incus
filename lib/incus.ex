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

  def handle(resp_tuple, %Endpoint{} = endpoint, opts \\ []) do
    case resp_tuple do
      {:ok, %Response{status: status, body: body} = response} when status in [200, 201, 202] ->
        if Keyword.get(opts, :response, false) do
          {:ok, response}
        else
          {:ok, body["metadata"]}
        end

      {:ok, %Req.Response{status: 404, body: %{"error" => error, "type" => "error"}}} ->
        Log.error(error)
        {:error, error}

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
      :ok -> start()
      :error -> :error
    end
  end

  def start() do
    :TODO_start
  end

  defp await_create(id, opts) do
    case Incus.Operations.wait(id, opts) do
      {:ok, %Req.Response{body: %{"status" => "Success"}}} ->
        Log.info("Instance created")
        :ok

      {:ok, %Req.Response{body: %{"error" => "context deadline exceeded"}}} ->
        Log.info("Timeout exceeded, instance may still be created")
        :ok

      {:ok, %Req.Response{body: %{"error" => error}}} ->
        Log.info("Instance creation error: #{error}")
        :error
    end
  end
end
