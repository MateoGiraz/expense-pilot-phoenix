# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     ExpensePilot.Repo.insert!(%ExpensePilot.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias ExpensePilot.Repo
alias ExpensePilot.Companies.Company
alias ExpensePilot.Accounts.User
alias ExpensePilot.Categories.Category
alias ExpensePilot.Expenses.Expense
alias ExpensePilot.Accounts
alias ExpensePilot.Companies

import Ecto.Query

ort_company =
  case Repo.one(from c in Company, where: c.name == "ORT", limit: 1) do
    nil ->
      Repo.insert!(%Company{
        name: "ORT",
        address: "Cuareim 1451, Montevideo, Uruguay",
        website: "https://www.ort.edu.uy",
        logo: "https://via.placeholder.com/150?text=ORT"
      })

    company ->
      company
  end

admin_user =
  Repo.get_by(User, email: "admin@saas.com") ||
    Repo.insert!(%User{
      email: "admin@saas.com",
      password_hash: Bcrypt.hash_pwd_salt("Password1"),
      role: "admin",
      company_id: ort_company.id,
      invited: false
    })

member_user =
  Repo.get_by(User, email: "usuario@ort.com") ||
    Repo.insert!(%User{
      email: "usuario@ort.com",
      password_hash: Bcrypt.hash_pwd_salt("Password1"),
      role: "member",
      company_id: ort_company.id,
      invited: false
    })

realistic_category_names = [
  "Alimentación",
  "Transporte",
  "Alojamiento",
  "Suministros de Oficina",
  "Marketing y Publicidad",
  "Salarios",
  "Impuestos",
  "Software y Herramientas",
  "Viajes de Negocios",
  "Entretenimiento"
]

# Crear categorías solo si hay menos de la cantidad de nombres realistas
category_count = Repo.aggregate(Category, :count, where: [company_id: ort_company.id])

if category_count < length(realistic_category_names) do
  categories_to_insert = Enum.drop(realistic_category_names, category_count)

  Enum.each(categories_to_insert, fn name ->
    Repo.insert!(%Category{
      name: name,
      description: "Gasto relacionado con #{String.downcase(name)}",
      expense_limit: Decimal.new(Enum.random(100..1000)),
      deleted: false,
      company_id: ort_company.id
    })
  end)

  inserted_count = length(categories_to_insert)
  IO.puts("Se insertaron #{inserted_count} categorías realistas.")
else
  IO.puts("Ya existen #{category_count} o más categorías para la empresa ORT.")
end

# Crear gastos solo si hay menos de 50
expense_count = Repo.aggregate(Expense, :count, where: [company_id: ort_company.id])

if expense_count < 50 do
  num_expenses_to_insert = 50 - expense_count

  # Obtener todas las categorías de la empresa ORT (actualizadas)
  ort_categories = Repo.all(from c in Category, where: c.company_id == ^ort_company.id)

  Enum.each(1..num_expenses_to_insert, fn _ ->
    unless Enum.empty?(ort_categories) do
      random_category = Enum.random(ort_categories)
      random_amount = Decimal.new(Enum.random(10..500))
      random_date = Date.utc_today() |> Date.add(Enum.random(-365..0)) # Gastos del último año
      random_registered_at = DateTime.utc_now()
      |> DateTime.add(Enum.random(-3600 * 24 * 365..0), :second)
      |> DateTime.truncate(:second) # Truncar a segundos

      Repo.insert!(%Expense{
        amount: random_amount,
        date: random_date,
        registered_at: random_registered_at,
        category_id: random_category.id,
        user_id: member_user.id, # Asignar los gastos al usuario miembro
        company_id: ort_company.id
      })
    end
  end)

  IO.puts("Se insertaron #{num_expenses_to_insert} gastos.")
else
  IO.puts("Ya existen 50 o más gastos para la empresa ORT.")
end

# Create a superadmin user if none exists
case Accounts.get_user_by_email("superadmin@example.com") do
  nil ->
    IO.puts("Creating superadmin user...")
    {:ok, superadmin} = Accounts.create_superadmin("superadmin@example.com", "password123")
    IO.puts("Superadmin created with ID: #{superadmin.id}")
  
  user ->
    IO.puts("Superadmin already exists with ID: #{user.id}")
end

# Create a demo company if none exists
case ExpensePilot.Repo.get_by(ExpensePilot.Companies.Company, name: "Demo Company") do
  nil ->
    IO.puts("Creating demo company...")
    {:ok, company} = Companies.create_company(%{
      name: "Demo Company",
      address: "123 Demo Street, Demo City, 12345",
      website: "https://www.democompany.com",
      logo: "https://via.placeholder.com/150?text=Demo"
    })
    IO.puts("Demo company created with ID: #{company.id}")
  
  company ->
    IO.puts("Demo company already exists with ID: #{company.id}")
end