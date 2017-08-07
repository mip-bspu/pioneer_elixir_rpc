defmodule PioneerRpc.Profile do

  import Ecto.{Query, Changeset}, warn: false
  import Ecto.Query, only: [from: 2]
  alias PioneerRpc.Profile.User
  alias PioneerRpc.Repo

  def get_user_by_login(login,password) do
    Repo.all from u in User,
      where: u.login == ^login and u.password == ^password,
      preload: [:groups,:subscription]
  end

end
