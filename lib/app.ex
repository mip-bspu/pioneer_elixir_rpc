defmodule App do


  def start(_,_) do

    children = [
      %{
        id: PioneerRpc.Example.RpcClient,
        start: { PioneerRpc.Example.RpcClient, :start_link, [[]]}
      },
      %{
        id: PioneerRpc.Example.RpcServer,
        start: { PioneerRpc.Example.RpcServer, :start_link, [[]]}
      }
    ]

    Supervisor.start_link(children, strategy: :one_for_one)

  end


end
