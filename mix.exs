defmodule PioneerRpc.Mixfile do
  use Mix.Project

  def project do
    [app: :pioneer_rpc,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end


  def application do
    [
      extra_applications: [:logger,:amqp,:ecto,],
      registered: [:pioneer_rpc],
      mod: {PioneerRpc.Application, []}
    ]
  end

  defp deps do
    [
      {:amqp, "~> 0.2.3"},
      {:poison, "~> 2.2"},
      {:plug, "~> 1.3.4"},
      {:ecto, "~> 2.1.6"},
      {:postgrex, ">= 0.0.0"},
    ]
  end
end
