defmodule Incus.Config do
  def remote do
    Application.get_env(:incus, :remote, default_remote())
  end

  defp default_remote() do
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
  end
end
