defmodule ExpensePilot.Factory do
  use ExMachina.Ecto, repo: ExpensePilot.Repo

  def company_factory do
    %ExpensePilot.Companies.Company{
      name: sequence(:name, &"Company #{&1}"),
      address: "Address",
      website: "https://example.com",
      logo: nil
    }
  end

  def api_key_factory do
    %ExpensePilot.Api.ApiKey{
      key: sequence(:key, &"key#{&1}"),
      company: build(:company)
    }
  end

  def user_factory do
    %ExpensePilot.Accounts.User{
      email: sequence(:email, &"user#{&1}@example.com"),
      password_hash: Bcrypt.hash_pwd_salt("password"),
      company: build(:company),
      role: "admin"
    }
  end

  def category_factory do
    %ExpensePilot.Categories.Category{
      name: sequence(:name, &"Category #{&1}"),
      description: "desc",
      expense_limit: nil,
      deleted: false,
      company: build(:company)
    }
  end

  def expense_factory do
    %ExpensePilot.Expenses.Expense{
      amount: 100,
      date: ~D[2024-01-01],
      registered_at: DateTime.utc_now(),
      category: build(:category),
      user: build(:user),
      company: build(:company)
    }
  end
end 