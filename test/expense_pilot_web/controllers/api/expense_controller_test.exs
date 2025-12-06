defmodule ExpensePilotWeb.Api.ExpenseControllerTest do
  use ExpensePilotWeb.ConnCase
  import ExpensePilot.Factory

  test "returns expenses for a category in date range", %{conn: conn} do
    company = insert(:company)
    api_key = insert(:api_key, company: company)
    user = insert(:user, company: company)
    category = insert(:category, company: company)
    e1 = insert(:expense, company: company, category: category, user: user, date: ~D[2024-01-10], amount: 100)
    e2 = insert(:expense, company: company, category: category, user: user, date: ~D[2024-01-15], amount: 200)
    _e3 = insert(:expense, company: company, category: category, user: user, date: ~D[2024-02-01], amount: 300)
    conn = put_req_header(conn, "x-api-key", api_key.key)
    url = "/api/categories/#{category.id}/expenses?date_from=2024-01-01&date_to=2024-01-31"
    resp = get(conn, url)
    ids = json_response(resp, 200)["data"] |> Enum.map(& &1["id"])
    assert Enum.sort(ids) == Enum.sort([e1.id, e2.id])
  end

  test "returns 401 if API key is missing", %{conn: conn} do
    resp = get(conn, "/api/categories/1/expenses?date_from=2024-01-01&date_to=2024-01-31")
    assert resp.status == 401
  end

  test "returns 404 if category does not exist", %{conn: conn} do
    company = insert(:company)
    api_key = insert(:api_key, company: company)
    conn = put_req_header(conn, "x-api-key", api_key.key)
    resp = get(conn, "/api/categories/9999/expenses?date_from=2024-01-01&date_to=2024-01-31")
    assert resp.status == 404
  end

  test "returns 400 if date format is invalid", %{conn: conn} do
    company = insert(:company)
    api_key = insert(:api_key, company: company)
    category = insert(:category, company: company)
    conn = put_req_header(conn, "x-api-key", api_key.key)
    resp = get(conn, "/api/categories/#{category.id}/expenses?date_from=invalid&date_to=2024-01-31")
    assert resp.status == 400
  end

  test "returns 400 if required params are missing", %{conn: conn} do
    company = insert(:company)
    api_key = insert(:api_key, company: company)
    category = insert(:category, company: company)
    conn = put_req_header(conn, "x-api-key", api_key.key)
    resp = get(conn, "/api/categories/#{category.id}/expenses")
    assert resp.status == 400
  end
end 