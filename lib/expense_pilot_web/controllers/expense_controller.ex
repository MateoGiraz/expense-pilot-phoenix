defmodule ExpensePilotWeb.ExpenseController do
  use ExpensePilotWeb, :controller
  require Logger

  alias ExpensePilot.Expenses
  alias ExpensePilot.Expenses.Expense
  alias ExpensePilot.Categories
  alias ExpensePilot.Accounts.User
  alias ExpensePilot.Companies
  alias ExpensePilot.AuditClient
  alias ExpensePilot.NotificationClient

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    company_id = get_company_id(conn, current_user)
    expenses = Expenses.list_expenses(company_id)
    render(conn, :index, expenses: expenses, current_user: current_user)
  end

  def new(conn, _params) do
    current_user = conn.assigns.current_user
    company_id = get_company_id(conn, current_user)
    categories = Categories.list_categories(company_id)
    changeset = Expenses.change_expense(%Expense{})
    render(conn, :new, changeset: changeset, categories: categories, current_user: current_user)
  end

  def create(conn, %{"expense" => expense_params}) do
    current_user = conn.assigns.current_user
    Logger.info("Creating expense - current_user: #{inspect(current_user)}")
    Logger.info("Creating expense - current_user.id: #{current_user.id}, current_user.email: #{current_user.email}")
    
    company_id = get_company_id(conn, current_user)
    Logger.info("Creating expense - company_id: #{company_id}")
    
    categories = Categories.list_categories(company_id)

    # Si es superadmin, asegúrate de agregar el company_id correcto
    expense_params = if User.is_superadmin?(current_user) do
      Map.put(expense_params, "company_id", company_id)
    else
      expense_params
    end
    
    Logger.info("Creating expense - expense_params: #{inspect(expense_params)}")
    Logger.info("Creating expense - will use user_id: #{current_user.id}")

    case Expenses.create_expense(expense_params, current_user) do
      {:ok, expense} ->
        Logger.info("Expense created successfully - expense.id: #{expense.id}, expense.user_id: #{expense.user_id}")
        
        # Log audit
        AuditClient.log_action(
          "create",
          "Expense",
          expense.id,
          current_user,
          company_id,
          %{
            amount: expense.amount,
            date: expense.date,
            category_id: expense.category_id,
            registered_at: expense.registered_at
          }
        )
        
        # Send expense notification asynchronously
        Task.start(fn ->
          NotificationClient.send_expense_notification(expense, "create", current_user)
        end)
        
        conn
        |> put_flash(:info, "Expense created successfully.")
        |> redirect(to: ~p"/expenses")

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Failed to create expense - changeset errors: #{inspect(changeset.errors)}")
        render(conn, :new, changeset: changeset, categories: categories, current_user: current_user)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    company_id = get_company_id(conn, current_user)
    expense = Expenses.get_expense!(id, company_id)
    render(conn, :show, expense: expense, current_user: current_user)
  end

  def edit(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    if current_user.role != "admin" && !User.is_superadmin?(current_user) do
      conn
      |> put_flash(:error, "Only administrators can edit expenses.")
      |> redirect(to: ~p"/expenses")
    else
      company_id = get_company_id(conn, current_user)
      expense = Expenses.get_expense!(id, company_id)
      categories = Categories.list_categories(company_id)
      changeset = Expenses.change_expense(expense)
      render(conn, :edit, expense: expense, changeset: changeset, categories: categories, current_user: current_user)
    end
  end

  def update(conn, %{"id" => id, "expense" => expense_params}) do
    current_user = conn.assigns.current_user

    if current_user.role != "admin" && !User.is_superadmin?(current_user) do
      conn
      |> put_flash(:error, "Only administrators can edit expenses.")
      |> redirect(to: ~p"/expenses")
    else
      company_id = get_company_id(conn, current_user)
      expense = Expenses.get_expense!(id, company_id)
      categories = Categories.list_categories(company_id)

      # Si es superadmin, asegúrate de agregar el company_id correcto
      expense_params = if User.is_superadmin?(current_user) do
        Map.put(expense_params, "company_id", company_id)
      else
        expense_params
      end

      case Expenses.update_expense(expense, expense_params, current_user) do
        {:ok, updated_expense} ->
          # Log audit
          AuditClient.log_action(
            "update",
            "Expense",
            updated_expense.id,
            current_user,
            company_id,
            %{
              old_data: %{
                amount: expense.amount,
                date: expense.date,
                category_id: expense.category_id,
                registered_at: expense.registered_at
              },
              new_data: %{
                amount: updated_expense.amount,
                date: updated_expense.date,
                category_id: updated_expense.category_id,
                registered_at: updated_expense.registered_at
              }
            }
          )
          
          # Send expense notification asynchronously
          Task.start(fn ->
            NotificationClient.send_expense_notification(updated_expense, "update", current_user)
          end)
          
          conn
          |> put_flash(:info, "Expense updated successfully.")
          |> redirect(to: ~p"/expenses")

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, :edit, expense: expense, changeset: changeset, categories: categories, current_user: current_user)
      end
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    if current_user.role != "admin" && !User.is_superadmin?(current_user) do
      conn
      |> put_flash(:error, "Only administrators can delete expenses.")
      |> redirect(to: ~p"/expenses")
    else
      company_id = get_company_id(conn, current_user)
      expense = Expenses.get_expense!(id, company_id)
      
      # Log audit before deletion
      AuditClient.log_action(
        "delete",
        "Expense",
        expense.id,
        current_user,
        company_id,
        %{
          amount: expense.amount,
          date: expense.date,
          category_id: expense.category_id,
          registered_at: expense.registered_at
        }
      )
      
      # Send expense notification asynchronously (before deletion)
      Task.start(fn ->
        NotificationClient.send_expense_notification(expense, "delete", current_user)
      end)
      
      {:ok, _expense} = Expenses.delete_expense(expense, current_user)

      conn
      |> put_flash(:info, "Expense deleted successfully.")
      |> redirect(to: ~p"/expenses")
    end
  end

  def toggle_notifications(conn, params) do
    current_user = conn.assigns.current_user
    
    # Only members can toggle their own notifications
    if current_user.role != "member" do
      conn
      |> put_flash(:error, "Only members can manage notification preferences.")
      |> redirect(to: ~p"/expenses")
    else
      # Toggle the notification preference
      enabled = params["expense_notifications"] == "true"
      
      case ExpensePilot.Accounts.update_user(current_user, %{expense_notifications: enabled}) do
        {:ok, _updated_user} ->
          message = if enabled do
            "Expense notifications enabled."
          else
            "Expense notifications disabled."
          end
          
          conn
          |> put_flash(:info, message)
          |> redirect(to: ~p"/expenses")
          
        {:error, _changeset} ->
          conn
          |> put_flash(:error, "Failed to update notification preferences.")
          |> redirect(to: ~p"/expenses")
      end
    end
  end

  # Helper para obtener el company_id correcto
  defp get_company_id(conn, user) do
    if User.is_superadmin?(user) do
      case conn.assigns do
        %{current_company_id: id} when is_binary(id) -> String.to_integer(id)
        %{current_company_id: id} when is_integer(id) -> id
        _ -> raise "Company not selected for superadmin"
      end
    else
      user.company_id
    end
  end
end
