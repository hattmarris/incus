defmodule Incus.Instances do
  alias Incus.Endpoint

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
      {:ok, %{"class" => "task", "description" => "Creating instance", ...}}
  """
  def post(body, opts \\ []) do
    endpoint = %Endpoint{method: "POST", version: "1.0", path: "/instances"}

    opts
    |> Incus.new()
    |> Req.post(url: endpoint.path, body: Jason.encode!(body))
    |> Incus.handle(endpoint, opts)
  end
end
