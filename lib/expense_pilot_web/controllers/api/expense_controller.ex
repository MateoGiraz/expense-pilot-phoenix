defmodule ExpensePilotWeb.Api.ExpenseController do
  use ExpensePilotWeb, :controller
  alias ExpensePilot.Expenses
  alias ExpensePilot.Categories
  alias ExpensePilotWeb.JsonHelpers

  def by_category(conn, %{"id" => category_id, "date_from" => date_from, "date_to" => date_to}) do
    company = conn.assigns.current_company

    with {:ok, parsed_date_from} <- Date.from_iso8601(date_from),
         {:ok, parsed_date_to} <- Date.from_iso8601(date_to),
         category when not is_nil(category) <- Categories.get_company_category(category_id, company.id) do

      expenses = Expenses.get_expenses_by_category(category_id, company.id, parsed_date_from, parsed_date_to)

      formatted_expenses = Enum.map(expenses, fn expense ->
        %{
          id: expense.id,
          amount: expense.amount,
          date: expense.date,
          registered_at: expense.registered_at,
          user: %{
            id: expense.user.id,
            email: expense.user.email
          }
        }
      end)

      response_data = %{
        data: formatted_expenses,
        meta: %{
          category: %{
            id: category.id,
            name: category.name,
            description: category.description
          },
          date_range: %{
            from: parsed_date_from,
            to: parsed_date_to
          }
        }
      }

      prepared_data = JsonHelpers.prepare_for_json(response_data)
      json(conn, prepared_data)
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Category not found or does not belong to your company"})

      {:error, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid date format. Please use YYYY-MM-DD format."})
    end
  end

  def by_category(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameters: id, date_from, date_to"})
  end
end
