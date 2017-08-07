defmodule PioneerRpc.Profile.Subscription do
  use Ecto.Schema

  schema "subscription" do

    field :name, :string
    field :until, :utc_datetime
    belongs_to :user, User

  end
end
