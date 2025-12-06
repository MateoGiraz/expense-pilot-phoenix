defmodule ExpensePilotWeb.InvitationController do
  use ExpensePilotWeb, :controller
  alias ExpensePilot.Accounts
  alias ExpensePilot.Accounts.User
  alias ExpensePilot.Companies
  alias ExpensePilot.Areas

  def index(conn, _params) do
    company_id = get_company_id_from_session(conn)
    
    if is_nil(company_id) do
      conn
      |> put_flash(:error, "No company associated with your account. Please contact support.")
      |> render(:index, invitations: [], pending_invitations: [])
    else
      invitations = Accounts.list_pending_invitations(company_id)
      render(conn, :index, invitations: invitations, pending_invitations: invitations)
    end
  end

  def new(conn, _params) do
    company_id = get_company_id_from_session(conn)
    
    if is_nil(company_id) do
      conn
      |> put_flash(:error, "No company associated with your account. Please contact support.")
      |> redirect(to: ~p"/admin/invitations")
    else
      areas = Areas.list_areas(company_id)
      render(conn, :new, areas: areas)
    end
  end

  def create(conn, %{"invitation" => invitation_params}) do
    company_id = get_company_id_from_session(conn)
    
    if is_nil(company_id) do
      conn
      |> put_flash(:error, "No company associated with your account. Please contact support.")
      |> redirect(to: ~p"/admin/invitations")
    else
      company = Companies.get_company!(company_id)

      # Always set role to member
      invitation_params = Map.put(invitation_params, "role", "member")
      
      # Extract area_id if provided
      area_id = if invitation_params["area_id"] != "", do: invitation_params["area_id"], else: nil

      case Accounts.invite_user(company, invitation_params["email"], invitation_params["role"], area_id) do
        {:ok, user} ->
          conn
          |> put_flash(:info, "Invitation sent successfully to #{user.email}!")
          |> redirect(to: ~p"/admin/invitations")

        {:error, :user_already_exists} ->
          conn
          |> put_flash(:error, "A user with this email already exists.")
          |> redirect(to: ~p"/admin/invitations")

        {:error, :auth_service_error} ->
          conn
          |> put_flash(:error, "Failed to create user in auth service. Please try again.")
          |> redirect(to: ~p"/admin/invitations")

        {:error, reason} ->
          conn
          |> put_flash(:error, "Failed to send invitation: #{inspect(reason)}")
          |> redirect(to: ~p"/admin/invitations")
      end
    end
  end

  def resend(conn, %{"id" => id}) do
    case Accounts.resend_invitation(id) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Invitation resent to #{user.email}!")
        |> redirect(to: ~p"/admin/invitations")

      {:error, :invalid_invitation} ->
        conn
        |> put_flash(:error, "Invalid invitation")
        |> redirect(to: ~p"/admin/invitations")

      {:error, :auth_service_error} ->
        conn
        |> put_flash(:error, "Failed to update user in auth service. Please try again.")
        |> redirect(to: ~p"/admin/invitations")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to resend invitation: #{inspect(reason)}")
        |> redirect(to: ~p"/admin/invitations")
    end
  end

  def cancel(conn, %{"id" => id}) do
    case Accounts.cancel_invitation(id) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Invitation cancelled successfully!")
        |> redirect(to: ~p"/admin/invitations")

      {:error, :invalid_invitation} ->
        conn
        |> put_flash(:error, "Invalid invitation")
        |> redirect(to: ~p"/admin/invitations")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to cancel invitation: #{inspect(reason)}")
        |> redirect(to: ~p"/admin/invitations")
    end
  end

  # Helper para obtener el company_id de la sesión
  defp get_company_id_from_session(conn) do
    company_id = get_session(conn, :company_id) || get_session(conn, "selected_company_id")
    
    case company_id do
      nil -> nil
      id when is_integer(id) -> id
      id when is_binary(id) -> 
        case Integer.parse(id) do
          {parsed_id, _} -> parsed_id
          :error -> nil
        end
      _ -> nil
    end
  end
end
