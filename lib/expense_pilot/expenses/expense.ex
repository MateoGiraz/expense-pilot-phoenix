defmodule ExpensePilot.Expenses.Expense do
  use Ecto.Schema
  import Ecto.Changeset

  schema "expenses" do
    field :date, :date
    field :amount, :decimal
    field :registered_at, :utc_datetime

    belongs_to :category, ExpensePilot.Categories.Category
    belongs_to :user, ExpensePilot.Accounts.User
    belongs_to :company, ExpensePilot.Companies.Company

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(expense, attrs) do
    expense
    |> cast(attrs, [:amount, :date, :registered_at, :category_id, :user_id, :company_id])
    |> validate_required([:amount, :date, :registered_at, :category_id, :user_id, :company_id])
  end
end
