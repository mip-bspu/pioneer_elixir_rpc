defmodule PioneerRpc.Stl.Food do
  use Ecto.Schema

  schema "food" do
     field :name, :string
     field :price, :integer
     field :weight, :string
     belongs_to :menu, Menu
     belongs_to :food_type, FoodType
  end

end
