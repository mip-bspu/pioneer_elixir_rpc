defmodule PioneerRpc.RpcServer do
  use PioneerRpc.RPC.PioneerRpc, [
    queues: ["sum","schoolInfo","auth"],
    # connetion_string: "amqp://10.1.1.200"
  ]

  alias PioneerRpc.Profile
  alias PioneerRpc.Profile.User

  def sum([a,b]), do: a+b
  def schoolInfo([id]), do: %{ id: id, name: "Школа #{id}", status: id }
  def auth([login,password]) do
    user = Profile.get_user_by_login(login,password)
    Logger.debug("user: #{user}")
  end

end
