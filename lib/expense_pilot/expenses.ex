defmodule ExpensePilot.Expenses do
  @moduledoc """
  The Expenses context.
  """

  import Ecto.Query, warn: false
  require Logger
  alias ExpensePilot.Repo
  alias ExpensePilot.Expenses.Expense
  alias ExpensePilot.Auditing

  def list_expenses(company_id) do
    from(e in Expense,
      where: e.company_id == ^company_id,
      order_by: [desc: e.date]
    )
    |> Repo.all()
    |> Repo.preload([:category, :user])
  end

  def list_expenses_by_date_range(company_id, start_date, end_date, limit \\ 10, offset \\ 0, category_id \\ nil, user_id \\ nil) do
    base_query = from e in Expense,
      where: e.company_id == ^company_id and
             e.date >= ^start_date and
             e.date <= ^end_date

    # Apply category filter if provided
    query = if category_id do
      from e in base_query, where: e.category_id == ^category_id
    else
      base_query
    end

    # Apply user filter if provided
    query = if user_id do
      from e in query, where: e.user_id == ^user_id
    else
      query
    end

    # Apply ordering, limit and offset
    query = from e in query,
      order_by: [desc: e.date],
      limit: ^limit,
      offset: ^offset

    expenses = Repo.all(query) |> Repo.preload([:category, :user])

    # Build count query with the same filters
    count_base_query = from e in Expense,
      where: e.company_id == ^company_id and
             e.date >= ^start_date and
             e.date <= ^end_date

    # Apply category filter to count query if provided
    count_query = if category_id do
      from e in count_base_query, where: e.category_id == ^category_id
    else
      count_base_query
    end

    # Apply user filter to count query if provided
    count_query = if user_id do
      from e in count_query, where: e.user_id == ^user_id
    else
      count_query
    end

    # Select count
    count_query = from e in count_query, select: count(e.id)

    total_count = Repo.one(count_query)

    %{
      expenses: expenses,
      total_count: total_count,
      page_size: limit,
      page: div(offset, limit) + 1,
      total_pages: ceil(total_count / limit)
    }
  end

  def aggregate_expenses_by_category(company_id, start_date, end_date) do
    # 1. Get total expenses for the period
    total_query = from e in Expense,
      where: e.company_id == ^company_id and
             e.date >= ^start_date and
             e.date <= ^end_date,
      select: sum(e.amount)

    total_expenses = Repo.one(total_query) || Decimal.new(0)

    # 2. Get expenses by category with additional information
    categories_query = from e in Expense,
      join: c in assoc(e, :category),
      where: e.company_id == ^company_id and
             e.date >= ^start_date and
             e.date <= ^end_date and
             c.deleted == false,
      group_by: [c.id, c.name, c.expense_limit],
      select: %{
        category_id: c.id,
        category_name: c.name,
        expense_limit: c.expense_limit,
        total: sum(e.amount)
      }

    categories = Repo.all(categories_query)

    # 3. Calculate percentages and sort by total amount
    Enum.map(categories, fn cat ->
      # Calculate percent of total
      percent_of_total = if Decimal.compare(total_expenses, Decimal.new(0)) == :gt do
        Decimal.div(cat.total, total_expenses)
        |> Decimal.mult(Decimal.new(100))
        |> Decimal.round(1)
      else
        Decimal.new(0)
      end

      # Calculate percent of limit
      percent_of_limit = if cat.expense_limit && Decimal.compare(cat.expense_limit, Decimal.new(0)) == :gt do
        Decimal.div(cat.total, cat.expense_limit)
        |> Decimal.mult(Decimal.new(100))
        |> Decimal.round(1)
      else
        nil
      end

      Map.merge(cat, %{
        percent_of_total: percent_of_total,
        percent_of_limit: percent_of_limit
      })
    end)
    |> Enum.sort_by(fn cat -> Decimal.to_float(cat.total) end, :desc)
  end

  def get_expense!(id, company_id) do
    from(e in Expense, where: e.id == ^id and e.company_id == ^company_id)
    |> Repo.one!()
    |> Repo.preload([:category, :user])
  end

  def create_expense(attrs, user) do
    Logger.info("Expenses.create_expense called with user: #{inspect(user)}")
    Logger.info("Expenses.create_expense - user.id: #{user.id}, user.email: #{user.email}")
    
    # For superadmin, use the company_id from the attrs
    company_id = user.company_id || attrs["company_id"]
    Logger.info("Expenses.create_expense - determined company_id: #{company_id}")
    
    attrs = Map.merge(attrs, %{
      "user_id" => user.id,
      "company_id" => company_id,
      "registered_at" => DateTime.utc_now()
    })
    
    Logger.info("Expenses.create_expense - final attrs: #{inspect(attrs)}")

    result = %Expense{}
    |> Expense.changeset(attrs)
    |> Repo.insert()

    case result do
      {:ok, expense} ->
        Logger.info("Expenses.create_expense - expense created with id: #{expense.id}, user_id: #{expense.user_id}")
        {:ok, expense}

      error -> 
        Logger.error("Expenses.create_expense - failed: #{inspect(error)}")
        error
    end
  end

  def update_expense(%Expense{} = expense, attrs, user) do
    result = expense
    |> Expense.changeset(attrs)
    |> Repo.update()

    case result do
      {:ok, updated_expense} ->
        {:ok, updated_expense}

      error -> error
    end
  end

  def delete_expense(%Expense{} = expense, user) do
    result = Repo.delete(expense)

    case result do
      {:ok, deleted_expense} ->
        {:ok, deleted_expense}

      error -> error
    end
  end

  def change_expense(%Expense{} = expense, attrs \\ %{}) do
    Expense.changeset(expense, attrs)
  end

  def get_current_month_date_range() do
    today = Date.utc_today()
    start_date = Date.new!(today.year, today.month, 1)

    # Get the last day of the month
    {year, month} = if today.month == 12 do
      {today.year + 1, 1}
    else
      {today.year, today.month + 1}
    end

    end_date = Date.add(Date.new!(year, month, 1), -1)

    {start_date, end_date}
  end

  @doc """
  Gets expenses by category for a company in a date range.
  """
  def get_expenses_by_category(category_id, company_id, date_from, date_to) do
    query = from e in Expense,
      where: e.category_id == ^category_id and e.company_id == ^company_id,
      order_by: [desc: e.date]

    query = if date_from, do: where(query, [e], e.date >= ^date_from), else: query
    query = if date_to, do: where(query, [e], e.date <= ^date_to), else: query

    Repo.all(query)
    |> Repo.preload([:user])
  end

  @doc """
  Gets expenses grouped by category for a company in a date range.
  Used for generating the dashboard chart.
  """
  def get_expenses_by_categories(company_id, date_from \\ nil, date_to \\ nil) do
    query = from e in Expense,
      join: c in assoc(e, :category),
      where: e.company_id == ^company_id and c.deleted == false,
      group_by: c.id,
      select: {c.name, sum(e.amount)}

    query = if date_from, do: where(query, [e], e.date >= ^date_from), else: query
    query = if date_to, do: where(query, [e], e.date <= ^date_to), else: query

    Repo.all(query)
  end

  @doc """
  Gets expenses for the current month for a company.
  Used for the initial dashboard view.
  """
  def get_current_month_expenses(company_id) do
    today = Date.utc_today()
    start_of_month = Date.beginning_of_month(today)
    end_of_month = Date.end_of_month(today)

    list_expenses_by_date_range(company_id, start_of_month, end_of_month)
  end
end
