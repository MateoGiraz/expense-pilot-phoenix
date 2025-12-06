defmodule ExpensePilot.Companies.Company do
  use Ecto.Schema
  import Ecto.Changeset

  schema "companies" do
    field :name, :string
    field :address, :string
    field :website, :string
    field :logo, :string

    has_many :users, ExpensePilot.Accounts.User
    has_many :areas, ExpensePilot.Areas.Area
    has_many :categories, ExpensePilot.Categories.Category
    has_many :expenses, ExpensePilot.Expenses.Expense
    has_many :api_keys, ExpensePilot.Api.ApiKey

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(company, attrs) do
    company
    |> cast(attrs, [:name, :address, :website, :logo])
    |> validate_required([:name, :address, :website, :logo])
    |> validate_format(:website, ~r/^https?:\/\/.+/, message: "must start with http:// or https://")
    |> foreign_key_constraint(:users, name: "users_company_id_fkey", message: "Cannot delete the company because it has associated users")
  end
end
