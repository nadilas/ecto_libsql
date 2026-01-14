defmodule EctoLibSql.Schemas.AccountUser do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  schema "account_users" do
    field(:role, :string)
    field(:account_id, :integer)
    field(:user_id, :integer)

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:account_id, :user_id, :role])
  end
end
