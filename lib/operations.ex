defmodule Incus.Operations do
  @moduledoc """
  Operations endpoints
  """
  alias Incus.Endpoint

  @doc """
  Waits for the operation to reach a final state (or timeout) and retrieve its final state.

  ## Parameters
    - `id`: Incus operation uuid string
    - `opts`: `:timeout` default is 10 seconds

  ## Examples

      iex> Incus.Operations.wait(id)
      {:ok, %Req.Response{body: %{"status" => "Success"}}}

      iex> Incus.Operations.wait(id, timeout: 1)
      {:ok, %Req.Response{body: %{"error" => "context deadline exceeded"}}}
  """
  @spec wait(String.t(), list) :: Req.Response.t()
  def wait(id, opts \\ []) do
    endpoint = %Endpoint{method: "GET", version: "1.0", path: "/operations/#{id}/wait"}

    params = %{timeout: Keyword.get(opts, :timeout, 10)}

    opts
    |> Incus.new()
    |> Req.get(url: endpoint.path, params: params)
  end

  def get(id, opts \\ []) do
    endpoint = %Endpoint{method: "GET", version: "1.0", path: "/operations/#{id}"}

    opts
    |> Incus.new()
    |> Req.get(url: endpoint.path)
  end
end
