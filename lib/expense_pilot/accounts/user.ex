defmodule ExpensePilot.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @roles ["member", "admin", "superadmin"]

  schema "users" do
    field :role, :string
    field :email, :string
    field :password_hash, :string
    field :invited, :boolean, default: false
    field :invitation_token, :string
    field :invitation_accepted_at, :utc_datetime
    field :invitation_sent_at, :utc_datetime
    field :expense_notifications, :boolean, default: true
    field :selected_company_id, :integer, virtual: true

    belongs_to :company, ExpensePilot.Companies.Company
    belongs_to :area, ExpensePilot.Areas.Area
    has_many :expenses, ExpensePilot.Expenses.Expense
    has_many :api_keys, ExpensePilot.Api.ApiKey

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password_hash, :role, :invited, :invitation_token,
                   :invitation_accepted_at, :invitation_sent_at, :company_id, :area_id, :expense_notifications])
    |> validate_required([:email, :password_hash, :role, :invited])
    |> validate_inclusion(:role, @roles)
    |> validate_company_required()
    |> unique_constraint(:email)
    |> update_change(:email, &String.downcase/1)
  end

  defp validate_company_required(%{changes: %{role: "superadmin"}} = changeset), do: changeset
  defp validate_company_required(changeset), do: validate_required(changeset, [:company_id])

  def roles, do: @roles
  def is_superadmin?(user), do: user.role == "superadmin"
end
