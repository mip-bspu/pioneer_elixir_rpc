defmodule PioneerRpc.Example.RpcClient do
  use PioneerRpc.PioneerRpcClient

  def sum(a,b), do: rpc({"sum",[a,b]})
  def schoolInfo(id), do: rpc({"schoolInfo",[id]})
  def auth(login,password), do: rpc({"auth",[login,password]})

end
