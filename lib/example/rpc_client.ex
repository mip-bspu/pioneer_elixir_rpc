defmodule PioneerRpc.Example.RpcClient do
  use PioneerRpc.PioneerRpcClient, connetion_string: "amqp://guest:guest@localhost"

  def sum(a,b), do: rpc({"sum",[a,b]})
  def schoolInfo(id), do: rpc({"schoolInfo",[id]})
  def auth(login,password), do: rpc({"auth",[login,password]})


 # PioneerRpc.Example.RpcClient.sum(34,56)
end
