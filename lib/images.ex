defmodule Incus.Images do
  alias Incus.Endpoint

  @doc """
  GET /1.0/images Get the images

  Returns a list of images (paths) or list of maps using :recursion opt.

  ## Examples

      iex> Incus.Images.get()
      {:ok, ["/1.0/images/4bd35e27cb8fsf5b4br6fbd9acbf401709c6828fa8r8e0329a3d50bg24832289"]}

      iex> Incus.Images.get(recursion: 1)
      {:ok, [%{"aliases" => [...] ...}]}
  """
  def get(opts \\ []) do
    endpoint = %Endpoint{method: "GET", version: "1.0", path: "/images"}

    params =
      opts
      |> Enum.reduce([], fn opt, acc ->
        case opt do
          o when o == :recursion or o in [recursion: 1, recursion: true] ->
            acc ++ [recursion: 1]

          :public ->
            acc ++ [:public]

          _ ->
            acc
        end
      end)

    opts
    |> Incus.new()
    |> Req.get(url: endpoint.path, params: params)
    |> Incus.handle(endpoint, opts)
  end

  @doc """
  GET /1.0/images/{fingerprint} Get the image

  Gets a specific image.

  ## Examples

      iex> Incus.Images.get_image("4bd35e27cb8fsf5b4br6fbd9acbf401709c6828fa8r8e0329a3d50bg24832289")
      {:ok, %{"aliases" => [], "architecture" => "x86_64", ... }}
  """
  def get_image("" <> fingerprint, opts \\ []) do
    endpoint = %Endpoint{
      method: "GET",
      version: "1.0",
      path: "/images/#{fingerprint}"
    }

    opts
    |> Incus.new()
    |> Req.get(url: endpoint.path)
    |> Incus.handle(endpoint, opts)
  end

  def delete(fingerprint, opts \\ []) do
    endpoint = %Endpoint{
      method: "DELETE",
      version: "1.0",
      path: "/images/#{fingerprint}"
    }

    opts
    |> Incus.new()
    |> Req.delete(url: endpoint.path)
    |> Incus.handle(endpoint, opts)
  end

  @doc """
  GET /1.0/images/aliases Get the image aliases

  Returns a list of image aliases (paths).

  ## Examples

      iex> Images.get_aliases()
      ["/1.0/images/aliases/alpine-elixir-1.18.2-otp-26"]

      iex> Images.get_aliases(short: true)
      ["alpine-elixir-1.18.2-otp-26"]
  """
  def get_aliases(opts \\ []) do
    endpoint = %Endpoint{
      method: "GET",
      version: "1.0",
      path: "/images/aliases"
    }

    short = Keyword.get(opts, :short, false)

    opts
    |> Incus.new()
    |> Req.get(url: endpoint.path)
    |> Incus.handle(endpoint, opts)
    |> then(fn {:ok, paths} ->
      if short do
        Enum.map(paths, &Path.basename(&1))
      else
        paths
      end
    end)
  end

  def rename_alias(from, to, opts \\ []) do
    endpoint = %Endpoint{
      method: "POST",
      version: "1.0",
      path: "/images/aliases/#{from}"
    }

    opts
    |> Incus.new()
    |> Req.post(url: endpoint.path, json: %{name: to})
    |> Incus.handle(endpoint, opts)
  end
end
