defmodule ExpensePilotWeb.PageControllerTest do
  use ExpensePilotWeb.ConnCase

  test "GET / redirects to login", %{conn: conn} do
    conn = get(conn, "/")
    assert redirected_to(conn) == "/login"
    assert conn.status == 302
  end
end
