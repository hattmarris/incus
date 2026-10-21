defmodule Incus.MixProject do
  use Mix.Project

  def project do
    [
      app: :incus,
      version: "0.1.0",
      elixir: "~> 1.20",
      deps: deps()
    ]
  end

  defp deps do
    [
      {:req, "~> 0.7.5"},
      {:websockex, "~> 0.5.1"}
    ]
  end
end
