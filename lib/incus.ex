defmodule Incus do
  alias Req.Response

  defmodule Endpoint do
    @enforce_keys [:method, :version, :path]
    @type t :: %__MODULE__{method: String.t(), version: String.t(), path: Path.t()}
    defstruct method: nil, version: nil, path: nil
  end

  alias Incus.Endpoint

  def new(opts \\ []) do
    case Keyword.get(opts, :server, :local) do
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

      {:error, _e} = error ->
        IO.warn("Error Req could not #{to_str(endpoint)}")
        error
    end
  end

  def images(opts \\ []) do
    endpoint = %Endpoint{method: "GET", version: "1.0", path: "/images"}

    params =
      if Keyword.get(opts, :recursion, false) do
        [recursion: 1]
      else
        []
      end

    opts
    |> new()
    |> Req.get(url: endpoint.path, params: params)
    |> handle(endpoint, opts)
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

  
end
