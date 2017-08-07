defmodule PioneerRpc.Repo.Migrations.InitStl do
  use Ecto.Migration

  def change do

      create table(:menu) do
        add :date, :date
        add :modification, :utc_datetime
        add :state, :string
      end

      create table(:food_type) do
        add :name, :string
        add :priority, :integer
      end

      create table(:food) do
        add :name, :string
        add :price, :integer
        add :weight, :string
        add :food_type_id, references(:food_type)
        add :menu_id, references(:menu)
      end

      create unique_index(:food_type, [:name], name: :unique_food_type_name)
      create unique_index(:menu, [:date], name: :unique_menu_date)
      create index(:food,[:menu_id],name: :food_menu_id_index)
  end
end
