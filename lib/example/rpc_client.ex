defmodule PioneerRpc.Example.RpcClient do
  use PioneerRpc.PioneerRpcClient, connetion_string: "amqp://core:123@10.1.1.200/pioneerApi"

  def sum(a,b), do: rpc({"sum",[a,b]})
  def schoolInfo(id), do: rpc({"schoolInfo",[id]})
  def auth(login,password), do: rpc({"auth",[login,password]})

end
