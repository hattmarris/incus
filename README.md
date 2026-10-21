# Incus

An Elixir client for the [Incus](https://linuxcontainers.org/incus/) API.

Incus is a modern manager for system containers and virtual machines (a community fork of LXD). This library aims to make that API feel natural to use from Elixir.

> **Status: work in progress.** The API is incomplete and may change without notice. Not yet published to Hex.

## Requirements

- Elixir `~> 1.20`
- A running Incus server you can reach (local or remote)
- Ubuntu / debian based:

```bash
sudo apt install incus
```

## Installation

The package isn't on Hex yet, so add it as a Git dependency in your `mix.exs`:

```elixir
def deps do
  [
    {:incus, github: "hattmarris/incus"}
  ]
end
```

Then fetch dependencies:

```sh
mix deps.get
```

## Dependencies

- [Req](https://hex.pm/packages/req) for HTTP requests to the Incus REST API
- [WebSockex](https://hex.pm/packages/websockex) for WebSocket connections

## Usage

### Create and start instances from images

```elixir
iex> Incus.launch(:alp, images: "alpine/3.21", type: :container, arch: :armv7l)
20:54:05.705 [info] [incus] Creating instance
20:54:07.564 [info] [incus] Instance created
:ok
20:54:07.564 [info] [incus] Instance started
```

### List instances 

```elixir
iex> Incus.list()
[
  %{
    "ipv4" => "10.232.198.65",
    "ipv6" => "fd42:c8f2:df36:7c:216:3eff:fe41:a3c0",
    "name" => "alp",
    "snapshots" => nil,
    "status" => "Running",
    "type" => "container"
  },
  %{
    "ipv4" => "10.232.198.55",
    "ipv6" => "fd42:c8f2:df36:7c:216:3eff:fe73:c4d2",
    "name" => "d1",
    "snapshots" => nil,
    "status" => "Running",
    "type" => "container"
  }
]
```

### Starting / stopping an instance

```elixir
iex(32)> Incus.start(:alp)
20:58:30.840 [info] [incus] Instance started (alp)
:ok
```

```elixir
iex(31)> Incus.stop(:alp)
20:58:11.215 [info] [incus] Instance stopped (alp)
:ok
```

## What's implemented

- [x] Connecting to an Incus server
- [x] Instances (list, get, create, start, stop, delete)
- [x] Images
- [ ] Networks
- [ ] Storage
- [ ] Events (WebSocket)

## Development

```sh
git clone https://github.com/hattmarris/incus.git
cd incus
mix deps.get
mix compile
```

## Contributing

Issues and pull requests are welcome. Since the project is early, please open an issue first to discuss larger changes.

## License

Released under the [MIT License](https://github.com/hattmarris/incus/LICENSE).

## Author

Matt Harris ([@hattmarris](https://github.com/hattmarris))
