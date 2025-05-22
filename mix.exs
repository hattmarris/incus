defmodule Incus.MixProject do
  use Mix.Project

  def project do
    [
      app: :incus,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: deps()
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5.6"},
      {:websockex, "~> 0.4.3"}
    ]
  end
end
