defmodule Incus.Images do
  alias Incus.Endpoint
  alias Incus.Log
  alias Incus.Operations

  @doc """
  Copy images between servers
  """
  def copy(image, opts \\ []) do
    remote = Keyword.get(opts, :remote)
    image_name = to_string(image)

    {:ok, images} = get(recursion: 1)
    image = Enum.find(images, fn i -> Enum.find(i["aliases"], &(&1["name"] == image_name)) end)

    if image do
      body = %{
        "source" => %{
          "mode" => "push",
          "fingerprint" => image["fingerprint"]
        }
      }

      {:ok, %{"metadata" => metadata}} = post(body, opts ++ [server: :remote])

      {:ok, %Req.Response{body: %{"metadata" => %{"id" => id}}}} =
        post_export(image["fingerprint"],
          certificate: Incus.cert!(server: :remote),
          target: remote,
          secret: metadata["secret"],
          server: :local
        )

      case Operations.wait(id) do
        {:ok, %Req.Response{body: %{"status_code" => 200}}} ->
          # Adding aliases in export call doesnt work, adds separate call
          {:ok, _} = post_aliases(image["fingerprint"], image_name, server: :remote)
          {:ok, "Image copied successfully!"}

        {:ok, %Req.Response{body: %{"error" => error}}} ->
          Log.error(error)
          {:error, "Error copying image"}
      end
    else
      {:error, "no image found"}
    end
  end

  @doc """
  POST /1.0/images Add an image

  Adds a new image to the image store.
  """
  def post(body, opts \\ []) do
    endpoint = %Endpoint{method: "POST", version: "1.0", path: "/images"}

    opts
    |> Incus.new()
    |> Req.post(url: endpoint.path, body: Jason.encode!(body))
    |> Incus.handle(endpoint, opts)
  end

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

  def post_export(fingerprint, opts \\ []) do
    endpoint = %Endpoint{
      method: "POST",
      version: "1.0",
      path: "/images/#{fingerprint}/export"
    }

    certificate = Keyword.get(opts, :certificate)
    secret = Keyword.get(opts, :secret)
    target = Keyword.get(opts, :target)

    body = %{
      "target" => target,
      "secret" => secret,
      "certificate" => certificate,
      "aliases" => [
        %{
          "name" => "light-app",
          "description" => ""
        }
      ]
    }

    opts
    |> Incus.new()
    |> Req.post(url: endpoint.path, body: Jason.encode!(body))
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

  def post_aliases(fingerprint, name, opts \\ []) do
    endpoint = %Endpoint{
      method: "POST",
      version: "1.0",
      path: "/images/aliases"
    }

    body =
      %{
        "target" => fingerprint,
        "name" => name
      }

    opts
    |> Incus.new()
    |> Req.post(url: endpoint.path, body: Jason.encode!(body))
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
