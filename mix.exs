defmodule SimultaneousAccessLock.Mixfile do
  use Mix.Project

  def project do
    [
      app: :simultaneous_access_lock,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {SimultaneousAccessLock.Application, []},
      extra_applications: [:logger, :redix, :poolboy]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:redix, "~> 0.6.1"},
      {:poolboy, "~> 1.5"},
      {:uuid, "~> 1.1" },
    ]
  end
end
