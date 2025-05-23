defmodule Incus.Websocket do
  use WebSockex

  alias Incus.Log

  def start(url, name, caller) do
    WebSockex.start(url, __MODULE__, %{name: name, caller: caller, buffer: []})
  end

  def handle_connect(conn, state) do
    debug(state, "Websocket connection - #{inspect(conn)}")
    send(state.caller, {:connected, conn})
    {:ok, state}
  end

  def handle_frame({:text, ""}, state) do
    debug(state, "Websocket Frame - text - \"\"")
    debug(state, "Received empty message - assuming disconnect")
    send(state.caller, {:disconnected, state.buffer})
    {:ok, clear_buffer(state)}
  end

  def handle_frame({type, msg}, state) do
    debug(state, "Websocket Frame - #{type} - #{inspect(msg)}")
    send(state.caller, {:data, msg})
    next = state.buffer ++ [msg]
    debug(state, "Next buffer - #{inspect(next)}")
    state = %{state | buffer: next}
    {:ok, state}
  end

  def handle_disconnect(_map, state) do
    debug(state, "Websocket disconnected")
    send(state.caller, {:disconnected, state.buffer})
    {:ok, clear_buffer(state)}
  end

  defp clear_buffer(state) do
    debug(state, "Buffer cleared - []")
    %{state | buffer: []}
  end

  defp debug(state, msg) do
    Log.debug("[#{state.name}] #{msg}")
  end

  def url(id, secret) do
    "wss://127.0.0.1:9443/1.0/operations/#{id}/websocket?secret=#{secret}"
  end
end
