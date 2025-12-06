defmodule ExpensePilotWeb.FallbackController do
  use ExpensePilotWeb, :controller

  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> put_root_layout(html: {ExpensePilotWeb.Layouts, :root})
    |> put_view(html: ExpensePilotWeb.ErrorHTML)
    |> render(:"404")
  end
end
