defmodule ExpensePilot.Categories do
  @moduledoc """
  The Categories context.
  """

  import Ecto.Query, warn: false
  alias ExpensePilot.Repo
  alias ExpensePilot.Categories.Category
  alias ExpensePilot.Expenses.Expense
  require Logger

  def list_categories(company_id) do
    Logger.info("Categories.list_categories for company_id: #{company_id}")
    result = from(c in Category, where: c.company_id == ^company_id and c.deleted == false)
    |> Repo.all()

    Logger.info("Found #{length(result)} categories")
    result
  end

  def list_categories_with_spending(company_id) do
    # First, get the categories
    categories = list_categories(company_id)

    # Get current month date range
    today = Date.utc_today()
    start_date = Date.new!(today.year, today.month, 1)
    {year, month} = if today.month == 12 do
      {today.year + 1, 1}
    else
      {today.year, today.month + 1}
    end
    end_date = Date.add(Date.new!(year, month, 1), -1)

    # Get expenses by category
    spending_by_category = Enum.reduce(categories, %{}, fn category, acc ->
      query = from e in Expense,
      where: e.company_id == ^company_id and
               e.category_id == ^category.id and
             e.date >= ^start_date and
             e.date <= ^end_date,
        select: sum(e.amount)

      total = Repo.one(query) || Decimal.new(0)
      Map.put(acc, category.id, total)
    end)

    # Attach spending data to categories
    Enum.map(categories, fn category ->
      current_spending = Map.get(spending_by_category, category.id, Decimal.new(0))
      spending_percent = if category.expense_limit && !Decimal.eq?(category.expense_limit, Decimal.new(0)) do
        Decimal.div(current_spending, category.expense_limit)
        |> Decimal.mult(Decimal.new(100))
        |> Decimal.round(1)
      else
        Decimal.new(0)
      end

      Map.merge(category, %{
        current_spending: current_spending,
        spending_percent: spending_percent
      })
    end)
  end

  def get_category!(id, company_id) do
    from(c in Category, where: c.id == ^id and c.company_id == ^company_id)
    |> Repo.one!()
  end

  @doc """
  Gets a category by id for a specific company.
  """
  def get_company_category(id, company_id) do
    Category
    |> where([c], c.id == ^id and c.company_id == ^company_id)
    |> Repo.one()
  end

  def create_category(attrs \\ %{}) do
    Logger.info("Categories.create_category with attrs: #{inspect(attrs)}")

    result = %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()

    case result do
      {:ok, category} ->
        Logger.info("Category created successfully: #{inspect(category)}")
      {:error, changeset} ->
        Logger.error("Category creation failed: #{inspect(changeset.errors)}")
    end

    result
  end

  def update_category(%Category{} = category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  def delete_category(%Category{} = category) do
    # Soft delete
    update_category(category, %{deleted: true})
  end

  def change_category(%Category{} = category, attrs \\ %{}) do
    Category.changeset(category, attrs)
  end

  @doc """
  Gets the top 3 categories with most expenses for a company.
  """
  def get_top_categories(company_id, limit \\ 3) do
    query = from c in Category,
      join: e in assoc(c, :expenses),
      where: c.company_id == ^company_id and c.deleted == false,
      group_by: c.id,
      select: {c, sum(e.amount)},
      order_by: [desc: sum(e.amount)],
      limit: ^limit

    Repo.all(query)
  end
end
