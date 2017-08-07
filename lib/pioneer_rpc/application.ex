defmodule PioneerRpc.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(PioneerRpc.Repo, []),
      supervisor(PioneerRpc.RpcServer, []),
    ]

    opts = [strategy: :one_for_one, name: PioneerRpc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
