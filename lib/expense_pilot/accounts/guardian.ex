defmodule ExpensePilot.Accounts.Guardian do
  use Guardian, otp_app: :expense_pilot

  alias ExpensePilot.Accounts

  def subject_for_token(user, _claims) do
    sub = user.email
    {:ok, sub}
  end

  @spec resource_from_claims(nil | maybe_improper_list() | map()) :: {:ok, any()}
  def resource_from_claims(claims) do
    email = claims["sub"]
    user = Accounts.get_user_by_email(email)
    {:ok, user}
  end

  def authenticate(email, password) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} -> create_token(user)
      error -> error
    end
  end

  def create_token(user) do
    {:ok, token, _claims} = encode_and_sign(user, %{role: user.role, company_id: user.company_id})
    {:ok, user, token}
  end
end
