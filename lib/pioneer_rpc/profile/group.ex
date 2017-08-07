defmodule PioneerRpc.Profile.Group do
  use Ecto.Schema

  schema "user" do

    field :name, :string
    many_to_many :users, User, join_through: "user_group"

  end
end
