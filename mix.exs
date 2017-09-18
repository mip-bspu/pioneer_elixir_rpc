defmodule PioneerRpc.Mixfile do
  use Mix.Project

  def project do
    [app: :pioneer_rpc,
     version: "0.1.1",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end


  def application do
    [
      extra_applications: [:logger,:amqp,],
      registered: [:pioneer_rpc],
      # mod: {PioneerRpc.Application, []}
    ]
  end

  defp deps do
    [

      {:poison, "~> 2.2"},
      {:amqp, "~> 0.2.3"},
    ]
  end
end
