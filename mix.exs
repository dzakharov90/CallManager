defmodule Ecallmanager.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecallmanager,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:uuid,:logger],
      mod: {Ecallmanager.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:poison, "~> 3.0"},
      {:plug, "~> 1.6"},
      {:cowboy, "~> 2.4"},
      {:credo, "~> 0.10", except: :prod, runtime: false},
      {:plug_cowboy, "~> 2.0"},
      {:elixml, "~> 0.1.1"},
      {:elixir_mod_event, "~> 0.0.10"},
      {:xml_builder, "~> 2.1"},
      {:jason, "~> 1.0"},
      {:postgrex, "~> 0.16.3"},
      {:json, "~> 1.4"},
      {:env, "~> 0.2.0"},
#      {:ex_syslogger, "~> 2.0"},
      {:event_socket_outbound, "~> 0.4.0"}
    ]
  end
end
