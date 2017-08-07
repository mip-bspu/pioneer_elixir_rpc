defmodule PioneerRpc.Repo.Migrations.InitProfile do
  use Ecto.Migration

  def change do

    create table(:user) do
      add :login, :string, unique: true, null: false
      add :password, :string
      add :active, :boolean, default: true
      add :name, :string
      add :surname, :string
      add :patronymic, :string
      add :description, :string
    end

    create table(:group) do
       add :name, :string
    end

    create table(:user_group,primary_key: false) do
       add :user_id, references(:user)
       add :group_id, references(:group)
    end

    create table(:subscription) do
       add :name, :string
       add :until, :utc_datetime
       add :user_id, references(:user)
    end

    create index(:subscription, [:name], name: :index_name_subscription)
    create index(:group, [:name], name: :index_name_group)
    create unique_index(:user, [:login], name: :unique_user_login)
  end
end
