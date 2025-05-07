defmodule Incus.Images do
  alias Incus.Endpoint

  def aliases(opts \\ []) do
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

  @doc """
  GET /1.0/images Get the images

  Returns a list of images (URLs).

  > Incus.Images.get()
  {:ok,
   ["/1.0/images/4bd35e27cb8fsf5b4br6fbd9acbf401709c6828fa8r8e0329a3d50bg24832289"]}
  """
  def get(opts \\ []) do
    endpoint = %Endpoint{method: "GET", version: "1.0", path: "/images"}

    params =
      if Keyword.get(opts, :recursion, false) do
        [recursion: 1]
      else
        []
      end

    opts
    |> Incus.new()
    |> Req.get(url: endpoint.path, params: params)
    |> Incus.handle(endpoint, opts)
  end

  @doc """
  GET /1.0/images/{fingerprint} Get the image

  Gets a specific image.

  > Incus.Images.get_image("4bd35e27cb8fsf5b4br6fbd9acbf401709c6828fa8r8e0329a3d50bg24832289")
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
