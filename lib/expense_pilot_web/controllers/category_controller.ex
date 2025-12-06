defmodule ExpensePilotWeb.CategoryController do
  use ExpensePilotWeb, :controller
  require Logger

  alias ExpensePilot.Categories
  alias ExpensePilot.Categories.Category
  alias ExpensePilot.Accounts.User
  alias ExpensePilot.Expenses
  alias ExpensePilot.AuditClient

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    company_id = get_company_id(conn, current_user)
    Logger.info("Listing categories for company_id: #{company_id}")
    
    # Use the same wider date range as the dashboard (all-time range)
    start_date = ~D[1970-01-01]
    end_date = Date.utc_today() |> Date.add(365)  # Future date to include all
    Logger.info("Date range: #{Date.to_string(start_date)} to #{Date.to_string(end_date)}")
    
    # Get all categories first
    categories = Categories.list_categories(company_id)
    Logger.info("Found #{length(categories)} categories")
    
    # Get spending data using the same method as dashboard
    spending_data = Expenses.aggregate_expenses_by_category(company_id, start_date, end_date)
    Logger.info("Spending data: #{inspect(spending_data)}")
    
    # Merge spending data into categories
    categories_with_spending = Enum.map(categories, fn category ->
      # Find spending data for this category
      category_spending = Enum.find(spending_data, fn sd -> 
        sd.category_id == category.id 
      end)
      
      Logger.info("Category #{category.name} (#{category.id}) spending: #{inspect(category_spending)}")
      
      # Set defaults if no spending found
      current_spending = if category_spending, do: category_spending.total, else: Decimal.new(0)
      spending_percent = if category_spending && category_spending.percent_of_limit do
        category_spending.percent_of_limit
      else
        if category.expense_limit && !Decimal.eq?(category.expense_limit, Decimal.new(0)) do
          Decimal.div(current_spending, category.expense_limit)
          |> Decimal.mult(Decimal.new(100))
          |> Decimal.round(1)
        else
          Decimal.new(0)
        end
      end
      
      Logger.info("Category #{category.name} (#{category.id}): spending=#{inspect(current_spending)}, percent=#{inspect(spending_percent)}")
      
      Map.merge(category, %{
        current_spending: current_spending,
        spending_percent: spending_percent
      })
    end)
    
    render(conn, :index, categories: categories_with_spending, current_user: current_user)
  end

  def new(conn, _params) do
    current_user = conn.assigns.current_user
    changeset = Categories.change_category(%Category{})
    render(conn, :new, changeset: changeset, current_user: current_user)
  end

  def create(conn, %{"category" => category_params}) do
    current_user = conn.assigns.current_user
    company_id = get_company_id(conn, current_user)
    Logger.info("Creating category with user_id: #{current_user.id}, company_id: #{company_id}")
    
    # Add company_id to category params
    category_params = Map.put(category_params, "company_id", company_id)
    Logger.info("Category params: #{inspect(category_params)}")

    case Categories.create_category(category_params) do
      {:ok, category} ->
        Logger.info("Category created successfully with id: #{category.id}, company_id: #{category.company_id}")
        
        # Log audit
        AuditClient.log_action(
          "create",
          "Category",
          category.id,
          current_user,
          company_id,
          %{
            name: category.name,
            description: category.description,
            expense_limit: category.expense_limit
          }
        )
        
        conn
        |> put_flash(:info, "Category created successfully.")
        |> redirect(to: ~p"/categories")

      {:error, changeset} ->
        Logger.error("Category creation failed: #{inspect(changeset.errors)}")
        render(conn, :new, changeset: changeset, current_user: current_user)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    company_id = get_company_id(conn, current_user)
    category = Categories.get_category!(id, company_id)
    render(conn, :show, category: category, current_user: current_user)
  end

  def edit(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    company_id = get_company_id(conn, current_user)
    category = Categories.get_category!(id, company_id)
    changeset = Categories.change_category(category)
    render(conn, :edit, category: category, changeset: changeset, current_user: current_user)
  end

  def update(conn, %{"id" => id, "category" => category_params}) do
    current_user = conn.assigns.current_user
    company_id = get_company_id(conn, current_user)
    category = Categories.get_category!(id, company_id)

    case Categories.update_category(category, category_params) do
      {:ok, updated_category} ->
        # Log audit
        AuditClient.log_action(
          "update",
          "Category",
          updated_category.id,
          current_user,
          company_id,
          %{
            old_data: %{
              name: category.name,
              description: category.description,
              expense_limit: category.expense_limit
            },
            new_data: %{
              name: updated_category.name,
              description: updated_category.description,
              expense_limit: updated_category.expense_limit
            }
          }
        )
        
        conn
        |> put_flash(:info, "Category updated successfully.")
        |> redirect(to: ~p"/categories")

      {:error, changeset} ->
        render(conn, :edit, category: category, changeset: changeset, current_user: current_user)
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    company_id = get_company_id(conn, current_user)
    category = Categories.get_category!(id, company_id)
    
    # Log audit before deletion
    AuditClient.log_action(
      "delete",
      "Category",
      category.id,
      current_user,
      company_id,
      %{
        name: category.name,
        description: category.description,
        expense_limit: category.expense_limit
      }
    )
    
    {:ok, _category} = Categories.delete_category(category)

    conn
    |> put_flash(:info, "Category deleted successfully.")
    |> redirect(to: ~p"/categories")
  end

  # Helper para obtener el company_id correcto
  defp get_company_id(conn, user) do
    company_id = if User.is_superadmin?(user) do
      case conn.assigns do
        %{current_company_id: id} when is_binary(id) -> id
        %{current_company_id: id} when is_integer(id) -> id
        _ -> raise "Company not selected for superadmin"
      end
    else
      user.company_id
    end
    
    ensure_integer(company_id)
  end

  # Ensure value is an integer
  defp ensure_integer(value) when is_integer(value), do: value
  defp ensure_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_value, _} -> int_value
      :error -> nil
    end
  end
  defp ensure_integer(_), do: nil
end 