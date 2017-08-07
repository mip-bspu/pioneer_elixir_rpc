defmodule PioneerRpc.Repo.Migrations.InitAccount do
  use Ecto.Migration

  def change do
      create table(:score) do
        add :balance, :integer
        add :dayLimit, :integer, default: 0
      end

      alter table(:user) do
        add :score_id, references(:score)
      end
  end
end
