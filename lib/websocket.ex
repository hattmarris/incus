defmodule Incus.Websocket do
  use WebSockex

  alias Incus.Log

  def start(url, name, caller) do
    WebSockex.start(url, __MODULE__, %{name: name, caller: caller, buffer: []})
  end

  def handle_connect(conn, state) do
    Log.debug("[#{state.name}] Websocket connection - #{inspect(conn)}")
    send(state.caller, {:connected, conn})
    {:ok, state}
  end

  def handle_frame({:text, ""}, state) do
    Log.debug("[#{state.name}] Websocket Frame - text - \"\"")
    Log.debug("Received empty message — assuming disconnect")
    send(state.caller, {:disconnected, state.buffer})
    next = []
    Log.debug("[#{state.name}] next buffer - #{next}")
    state = %{state | buffer: next}
    {:ok, state}
  end

  def handle_frame({type, msg}, state) do
    Log.debug("[#{state.name}] Websocket Frame - #{type} - #{inspect(msg)}")
    send(state.caller, {:data, msg})
    next = state.buffer ++ [msg]
    Log.debug("[#{state.name}] next buffer - #{inspect(next)}")
    state = %{state | buffer: next}
    {:ok, state}
  end

  def handle_disconnect(_map, state) do
    Log.debug("[#{state.name}] Websocket disconnected")
    send(state.caller, {:disconnected, state.buffer})
    next = []
    Log.debug("[#{state.name}] next buffer - #{next}")
    state = %{state | buffer: next}
    {:ok, state}
  end

  def url(id, secret) do
    "wss://127.0.0.1:9443/1.0/operations/#{id}/websocket?secret=#{secret}"
  end
end
