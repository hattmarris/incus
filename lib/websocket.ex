defmodule Incus.Websocket do
  use WebSockex

  alias Incus.Log

  def start(url, name, caller) do
    WebSockex.start_link(url, __MODULE__, %{name: name, caller: caller, buffer: []})
  end

  def task(url, name, timeout) do
    Task.async(fn ->
      start(url, name, self())
      listen(timeout)
    end)
  end

  def listen(timeout) do
    receive do
      {:data, data} ->
        data
        |> String.split("\n")
        |> Enum.map(fn
          "" -> nil
          "" <> str -> Log.info(str)
          other -> Log.error(other)
        end)

        listen(timeout)

      {:connected, _conn} ->
        listen(timeout)

      {:disconnected, buffer} ->
        {:ok, buffer}

      other ->
        Log.debug("Unexpected message received #{inspect(other)}")
        {:error, other}
    after
      timeout ->
        Log.error("Longer than #{timeout} with no message from Incus.Websocket")
        {:error, :timeout}
    end
  end

  def handle_connect(conn, state) do
    debug(state, "Websocket connection - #{inspect(conn)}")
    send(state.caller, {:connected, conn})
    {:ok, state}
  end

  def handle_frame({:text, ""}, state) do
    debug(state, "Websocket Frame - text - \"\"")
    debug(state, "Received empty message - assuming close")
    send(state.caller, {:disconnected, state.buffer})
    {:close, clear_buffer(state)}
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

  def terminate(reason, state) do
    debug(state, "Socket Terminating: #{inspect(reason)} #{inspect(state)}")
    exit(:normal)
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
