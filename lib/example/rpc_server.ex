defmodule PioneerRpc.Example.RpcServer do
  use PioneerRpc.PioneerRpcServer, [
    queues: ["sum","schoolInfo","auth"],
     connetion_string: "amqp://guest:guest@localhost",
  ]



  def sum(a,b), do: a+b
  def schoolInfo(id), do: %{ id: id, name: "Школа #{id}", status: id }
  def auth(login,password) do
    login == password
  end

  def urpc(args) do
    IO.inspect(args)
    :ok
  end

end
