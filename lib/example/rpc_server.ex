defmodule PioneerRpc.Example.RpcServer do
  use PioneerRpc.PioneerRpcServer, [
    queues: ["sum","schoolInfo","auth"],
    # connetion_string: "amqp://10.1.1.200"
  ]


  def sum([a,b]), do: a+b
  def schoolInfo([id]), do: %{ id: id, name: "Школа #{id}", status: id }
  def auth([login,password]) do
    login == password
  end

end
