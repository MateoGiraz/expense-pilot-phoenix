defmodule ExpensePilotWeb.Api.CategoryControllerTest do
  use ExpensePilotWeb.ConnCase
  import ExpensePilot.Factory

  test "returns top 3 categories with most expenses", %{conn: conn} do
    company = insert(:company)
    api_key = insert(:api_key, company: company)
    cat1 = insert(:category, company: company)
    cat2 = insert(:category, company: company)
    cat3 = insert(:category, company: company)
    cat4 = insert(:category, company: company)
    insert(:expense, company: company, category: cat1, amount: 100)
    insert(:expense, company: company, category: cat2, amount: 200)
    insert(:expense, company: company, category: cat3, amount: 300)
    insert(:expense, company: company, category: cat4, amount: 50)

    conn = put_req_header(conn, "x-api-key", api_key.key)
    resp = get(conn, "/api/top-categories")
    assert json_response(resp, 200)["data"] |> Enum.map(& &1["id"]) == [cat3.id, cat2.id, cat1.id]
  end

  test "returns 401 if API key is missing", %{conn: conn} do
    resp = get(conn, "/api/top-categories")
    assert resp.status == 401
  end
end 