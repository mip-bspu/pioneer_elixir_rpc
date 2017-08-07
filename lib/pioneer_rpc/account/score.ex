defmodule PioneerRpc.Account.Score do
  use Ecto.Schema

  alias PioneerRpc.Profile.User

  @primary_key {:id, :id, autogenerate: false}

  schema "score" do
    field :balance, :integer
    field :dayLimit, :integer, default: 0
    has_many :users, User
  end

end
