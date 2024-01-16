defmodule PioneerRpc.Mixfile do
  use Mix.Project

  def project do
    [app: :pioneer_rpc,
     version: "0.1.4",
     elixir: "~> 1.4",
     build_embedded: Mix.env() == :prod,
     start_permanent: Mix.env() == :prod,
     deps: deps()]
  end


  def application do
    [

      extra_applications: [:logger,:amqp,],
      registered: [:pioneer_rpc],
      # mod: {App, []}
    ]
  end

  defp deps do
    [
      {:poison, "~> 4.0.1", override: true},
      {:amqp, "~> 3.2"},
    ]
  end
end
