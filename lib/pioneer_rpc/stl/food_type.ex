defmodule PioneerRpc.Stl.FoodType do
  use Ecto.Schema

  schema "food_type" do
     field :name, :string
     field :priority, :integer
     has_many :foods, Food
  end

end
