defmodule ExpensePilot.Categories.Category do
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  schema "categories" do
    field :name, :string
    field :description, :string
    field :expense_limit, :decimal
    field :deleted, :boolean, default: false

    belongs_to :company, ExpensePilot.Companies.Company
    has_many :expenses, ExpensePilot.Expenses.Expense

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(category, attrs) do
    Logger.info("Category changeset with attrs: #{inspect(attrs)}")

    result = category
    |> cast(attrs, [:name, :description, :expense_limit, :deleted, :company_id])
    |> validate_required([:name, :description, :deleted, :company_id])

    if result.valid? do
      Logger.info("Category changeset valid")
    else
      Logger.error("Category changeset invalid: #{inspect(result.errors)}")
    end

    result
  end
end
