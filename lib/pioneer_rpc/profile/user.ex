defmodule PioneerRpc.Profile.User do
  use Ecto.Schema

  alias PioneerRpc.Account.Score

  schema "user" do

    field :login, :string
    field :password, :string

    field :active, :boolean

    field :name, :string
    field :surname, :string
    field :patronymic, :string
    field :description, :string

    has_many :subscription, Subscription
    many_to_many :groups, Group, join_through: "user_group"

    belongs_to :score, Score

  end
end
