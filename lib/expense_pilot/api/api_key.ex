defmodule ExpensePilot.Api.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_keys" do
    field :key, :string
    field :name, :string

    belongs_to :user, ExpensePilot.Accounts.User
    belongs_to :company, ExpensePilot.Companies.Company

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :user_id, :company_id])
    |> validate_required([:name, :user_id, :company_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:company_id)
    |> generate_api_key()
  end

  defp generate_api_key(changeset) do
    if changeset.valid? do
      key = :crypto.strong_rand_bytes(32) |> Base.encode64()
      put_change(changeset, :key, key)
    else
      changeset
    end
  end
end
