defmodule Incus.Log do
  @moduledoc """
  Wrapper for Logger
  """
  require Logger

  def info(msg), do: do_log(&Logger.info/1, msg)
  def debug(msg), do: do_log(&Logger.debug/1, msg)
  def error(msg), do: do_log(&Logger.error/1, msg)

  defp do_log(func, msg) do
    formatted = "[incus] #{format(msg)}"
    func.(formatted)
    msg
  end

  defp format(msg) when is_map(msg) or is_tuple(msg) or is_list(msg), do: inspect(msg)
  defp format(msg), do: msg
end
