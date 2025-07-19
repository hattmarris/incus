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

  def cert!(opts \\ []) do
    case Incus.new(opts) |> Req.get() do
      {:ok, %Req.Response{body: %{"metadata" => %{"environment" => environment}}}} ->
        environment["certificate"]
    end
  end

  @type resp_t :: {:ok, Req.Response.t() | map} | {:error, Req.Response.t() | String.t()}
  @spec handle(tuple, Endpoint.t(), list) :: resp_t
  def handle(resp_tuple, %Endpoint{} = endpoint, opts \\ []) do
    Log.debug(resp_tuple)
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

  def list(opts \\ []) do
    opts = Keyword.merge(opts, recursion: 2)

    case Instances.get(opts) do
      {:ok, list} ->
        Enum.map(list, fn map ->
          out =
            map
            |> Map.take(["name", "status", "type", "snapshots"])

          case map do
            %{"state" => %{"status_code" => 102}} ->
              out

            %{"state" => %{"status_code" => 103}} ->
              ipv4 =
                map
                |> get_in(["state", "network", "eth0", "addresses"])
                |> Enum.find_value(&if &1["family"] == "inet", do: &1["address"])

              ipv6 =
                map
                |> get_in(["state", "network", "eth0", "addresses"])
                |> Enum.find_value(&if &1["family"] == "inet6", do: &1["address"])

              Map.merge(out, %{"ipv4" => ipv4, "ipv6" => ipv6})
          end
        end)
    end
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
        config: Keyword.get(opts, :config),
        devices: Keyword.get(opts, :devices),
        source: source,
        type: Keyword.get(opts, :type, :container),
        start: true
      }
      |> Map.reject(fn {_k, v} -> is_nil(v) end)
      |> Log.debug()
      |> Instances.post(opts)

    Log.info("Creating instance")

    case await_create(id, Keyword.take(opts, [:timeout, :server])) do
      # :ok -> start(name, Keyword.take(opts, [:server]))
      :ok -> Log.info("Instance started")
      :error -> :error
    end
  end

  def exec(name, cmd_str, opts \\ []) do
    command =
      cmd_str
      |> String.split(" ")
      |> Enum.map(&String.trim(&1))
      |> Log.debug()

    body =
      %{
        "command" => command,
        "wait-for-websocket" => true,
        "interactive" => true,
        "environment" => %{
          "TERM" => "xterm-256color"
        },
        "width" => 102,
        "height" => 54,
        "user" => 0,
        "group" => 0,
        "cwd" => Keyword.get(opts, :cwd, "")
      }

    Instances.exec(name, body)
  end

  def file_pull(name, instance_path, local_path, opts \\ []) do
    recursive = Keyword.get(opts, :r, false)

    if recursive do
      recursive_file_pull(name, instance_path, local_path, opts)
    else
      single_file_pull(name, instance_path, local_path, opts)
    end
  end

  defp recursive_file_pull(name, i_dir, dir, opts) do
    opts = Keyword.merge(opts, response: true)

    files =
      case Incus.Instances.get_files(name, i_dir, opts) do
        {:ok, %Req.Response{headers: %{"x-incus-type" => ["directory"]}, body: body}} ->
          body["metadata"]
      end

    results =
      Enum.reduce(files, [], fn file, acc ->
        path = Path.join([dir, file])
        i_path = Path.join([i_dir, file])

        case Incus.Instances.head_files(name, i_path, opts) do
          {:ok, %Req.Response{headers: %{"x-incus-type" => ["file"]}}} ->
            resp =
              single_file_pull(name, i_path, path, opts)

            acc ++ [{:file, file, resp}]

          {:ok, %Req.Response{headers: %{"x-incus-type" => ["directory"]}}} ->
            {:ok, res} = recursive_file_pull(name, i_path, path, opts)
            acc ++ [{:dir, file, res}]
        end
      end)

    {:ok, results}
  end

  defp single_file_pull(name, instance_path, local_path, opts) do
    opts = Keyword.merge(opts, response: true)

    Log.info("Pulling #{instance_path} to #{local_path}")

    case Incus.Instances.get_files(name, instance_path, opts) do
      {:ok, %Req.Response{headers: %{"x-incus-type" => ["file"]}, body: file}} ->
        local_path
        |> Path.dirname()
        |> File.mkdir_p!()

        File.write!(local_path, file)
    end
  end

  def file_push(name, local_path, instance_path, opts \\ []) do
    recursive = Keyword.get(opts, :r, false)

    if recursive do
      recursive_file_push(name, local_path, instance_path, opts)
    else
      single_file_push(name, local_path, instance_path, opts)
    end
  end

  defp recursive_file_push(name, dir, i_dir, opts) do
    {:ok, _, _} = exec(name, "mkdir -p #{i_dir}")
    files = File.ls!(dir)

    results =
      Enum.reduce(files, [], fn file, acc ->
        path = Path.join([dir, file])
        i_path = Path.join([i_dir, file])

        case File.lstat!(path) do
          %File.Stat{type: :regular} ->
            resp =
              single_file_push(name, path, i_path, opts)

            acc ++ [{:file, file, resp}]

          %File.Stat{type: :directory} ->
            {:ok, res} = recursive_file_push(name, path, i_path, opts)
            acc ++ [{:dir, file, res}]
        end
      end)

    {:ok, results}
  end

  defp single_file_push(name, local_path, instance_path, opts) do
    file = File.read!(local_path)

    Log.info("Pushing #{local_path} to #{instance_path}")

    Instances.post_files(name, file, instance_path, opts)
  end

  def start(name, opts \\ []) do
    {:ok, %{"id" => id}} =
      Instances.put_state(
        name,
        %{
          action: "start",
          timeout: 0,
          force: false,
          stateful: false
        },
        opts
      )

    case Operations.wait(id, opts) do
      {:ok, %Req.Response{body: %{"status_code" => 200}}} ->
        Log.info("Instance started (#{name})")
        :ok

      {:ok, %Req.Response{body: %{"error" => error}}} ->
        Log.error("Error starting instance: #{error}")
        :error
    end
  end

  def stop(name, opts \\ []) do
    {:ok, %{"id" => id}} =
      Instances.put_state(
        name,
        %{
          action: "stop",
          timeout: -1,
          force: false,
          stateful: false
        },
        opts
      )

    case Operations.wait(id, opts) do
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

  def publish(name, opts \\ []) do
    alias_name = Keyword.get(opts, :alias)

    # TODO: determine minimal body
    body = %{
      "aliases" => nil,
      "auto_update" => false,
      "compression_algorithm" => "",
      "expires_at" => "0001-01-01T00:00:00Z",
      "filename" => "",
      "profiles" => nil,
      "properties" => nil,
      "public" => false,
      "source" => %{
        "alias" => "",
        "certificate" => "",
        "fingerprint" => "",
        "image_type" => "",
        "mode" => "",
        "name" => name,
        "project" => "",
        "protocol" => "",
        "secret" => "",
        "server" => "",
        "type" => "instance",
        "url" => ""
      }
    }

    body =
      if alias_name do
        Map.put(body, "aliases", [%{"description" => "", "name" => alias_name}])
      else
        body
      end

    {:ok, %{"id" => id}} = Incus.Images.post(body, opts)

    case Operations.wait(id) do
      {:ok, %Req.Response{body: %{"status_code" => 200, "metadata" => data}}} ->
        Log.info("Image published with fingerprint: #{data["metadata"]["fingerprint"]}")
        :ok

      {:ok, %Req.Response{body: %{"error" => error}}} ->
        Log.error("Error publishing image: #{error}")
        :error
    end
  end
end
