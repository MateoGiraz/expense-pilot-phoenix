defmodule ExpensePilotWeb.Api.CategoryController do
  use ExpensePilotWeb, :controller
  alias ExpensePilot.Categories

  def top(conn, _params) do
    company = conn.assigns.current_company
    top_categories = Categories.get_top_categories(company.id)

    formatted_categories = Enum.map(top_categories, fn {category, amount} ->
      %{
        id: category.id,
        name: category.name,
        description: category.description,
        total_expenses: Decimal.to_string(amount)
      }
    end)

    prepared_data = %{data: formatted_categories}
    json(conn, prepared_data)
  end
end
