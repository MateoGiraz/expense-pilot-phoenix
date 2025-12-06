defmodule ExpensePilotWeb.DashboardController do
  use ExpensePilotWeb, :controller

  alias ExpensePilot.Expenses
  alias ExpensePilot.Categories
  alias ExpensePilot.Accounts
  alias ExpensePilotWeb.JsonHelpers
  alias ExpensePilot.Accounts.User

  def index(conn, params) do
    current_user = conn.assigns.current_user
    conn = assign(conn, :layout_width, "max-w-7xl")

    # Get the appropriate company_id (either from current_user or from session for superadmins)
    company_id = if User.is_superadmin?(current_user) do
      case conn.assigns do
        %{current_company_id: id} when is_binary(id) -> String.to_integer(id)
        %{current_company_id: id} when is_integer(id) -> id
        _ -> raise "Company not selected for superadmin"
      end
    else
      current_user.company_id
    end

    # Check if we're in reset mode
    _is_reset = !Map.has_key?(params, "start_date") &&
               !Map.has_key?(params, "end_date") &&
               !Map.has_key?(params, "category_id") &&
               !Map.has_key?(params, "user_id") &&
               !Map.has_key?(params, "page")

    # Get date range (default to all data when no filters applied)
    {data_start_date, data_end_date, display_start_date, display_end_date} = case params do
      %{"start_date" => start_str, "end_date" => end_str}
      when start_str != "" and end_str != "" ->
        start_date = Date.from_iso8601!(start_str)
        end_date = Date.from_iso8601!(end_str)
        {start_date, end_date, start_str, end_str}

      %{"start_date" => start_str}
      when start_str != "" ->
        start_date = Date.from_iso8601!(start_str)
        end_date = Date.utc_today()
        {start_date, end_date, start_str, ""}

      %{"end_date" => end_str}
      when end_str != "" ->
        # If only end date is specified, go back 30 days as default
        end_date = Date.from_iso8601!(end_str)
        start_date = Date.add(end_date, -30)
        {start_date, end_date, "", end_str}

      _ ->
        # For no filters, get all-time range
        start_date = ~D[1970-01-01]
        end_date = Date.utc_today() |> Date.add(365)  # Future date to include all
        {start_date, end_date, "", ""}
    end

    # Get category filter
    category_id_param = case params do
      %{"category_id" => category_id} when category_id != "" ->
        String.to_integer(category_id)
      _ ->
        nil
    end

    # Get user filter
    user_id_param = case params do
      %{"user_id" => user_id} when user_id != "" ->
        String.to_integer(user_id)
      _ ->
        nil
    end

    # Get page parameters
    page = Map.get(params, "page", "1") |> String.to_integer()
    page_size = 8  # Set a reasonable default
    offset = (page - 1) * page_size

    # Get expenses for the date range with pagination
    paginated_expenses = Expenses.list_expenses_by_date_range(
      company_id,
      data_start_date,
      data_end_date,
      page_size,
      offset,
      category_id_param,
      user_id_param
    )

    # Get category aggregation for the chart
    category_data = Expenses.aggregate_expenses_by_category(
      company_id,
      data_start_date,
      data_end_date
    )

    # Get all categories for the filter dropdown
    categories = Categories.list_categories(company_id)

    # Get all users for the filter dropdown
    users = Accounts.list_users(company_id)

    # Prepare chart data
    chart_data = %{
      labels: Enum.map(category_data, fn cat -> cat.category_name end),
      values: Enum.map(category_data, fn cat -> cat.total end)
    }

    # Pre-process the chart data for Jason encoding
    prepared_chart_data = JsonHelpers.prepare_for_json(chart_data)
    # Pre-process category data for Jason encoding if needed in the template
    prepared_category_data = JsonHelpers.prepare_for_json(category_data)

    render(conn, :index,
      expenses: paginated_expenses.expenses,
      page: paginated_expenses.page,
      total_pages: paginated_expenses.total_pages,
      start_date: display_start_date,
      end_date: display_end_date,
      chart_data: prepared_chart_data,
      category_data: prepared_category_data,
      total_count: paginated_expenses.total_count,
      current_user: current_user,
      categories: categories,
      users: users,
      selected_category_id: category_id_param,
      selected_user_id: user_id_param
    )
  end
end
