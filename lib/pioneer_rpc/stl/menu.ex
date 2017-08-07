defmodule PioneerRpc.Stl.Menu do
  use Ecto.Schema

  schema "menu" do
    field :date, :date
    field :modification, :utc_datetime
    field :state, :string
    has_many :foods, Food
  end

end
