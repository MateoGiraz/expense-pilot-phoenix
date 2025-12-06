defmodule ExpensePilotWeb.Router do
  use ExpensePilotWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExpensePilotWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug :browser
    plug ExpensePilotWeb.Plugs.EnsureAuthentication
  end

  pipeline :with_company do
    plug ExpensePilotWeb.Plugs.EnsureCompanySelected
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug ExpensePilotWeb.Plugs.ApiAuth
  end

  pipeline :admin do
    plug :authenticated
    plug :with_company
    plug ExpensePilotWeb.Plugs.EnsureAdmin
  end

  pipeline :superadmin do
    plug :authenticated
    plug ExpensePilotWeb.Plugs.EnsureSuperadmin
  end

  scope "/", ExpensePilotWeb do
    pipe_through :browser

    get "/login", SessionController, :new
    post "/login", SessionController, :create
    get "/logout", SessionController, :delete
  end

  # Company selector for superadmin
  scope "/company-selector", ExpensePilotWeb do
    pipe_through :superadmin
    
    get "/", CompanySelectorController, :index
    post "/select", CompanySelectorController, :select
  end

  # Authenticated routes
  scope "/", ExpensePilotWeb do
    pipe_through [:authenticated, :with_company]

    get "/", DashboardController, :index

    resources "/expenses", ExpenseController
    post "/expenses/toggle-notifications", ExpenseController, :toggle_notifications
    resources "/categories", CategoryController
    resources "/areas", AreaController
  end

  # Admin routes that require company context
  scope "/admin", ExpensePilotWeb do
    pipe_through :admin
    resources "/api-keys", ApiKeyController, only: [:index, :new, :create, :delete]
    resources "/invitations", InvitationController, only: [:index, :new, :create, :delete]
    post "/invitations/:id/resend", InvitationController, :resend, as: :invitation_resend
    resources "/audit-logs", AuditLogController, only: [:index, :show]
  end

  # Superadmin routes for company management
  scope "/admin", ExpensePilotWeb do
    pipe_through [:superadmin]
    resources "/companies", CompanyController
  end

  # API routes
  scope "/api", ExpensePilotWeb.Api, as: :api do
    pipe_through :api_auth

    # Top 3 categories
    get "/top-categories", CategoryController, :top

    # Expenses for a category
    get "/categories/:id/expenses", ExpenseController, :by_category
  end

  # Health check
  scope "/health", ExpensePilotWeb do
    pipe_through :api

    get "/", HealthCheckController, :index
  end

  # Catch-all route for unmatched paths
  scope "/", ExpensePilotWeb do
    pipe_through :browser
    match :*, "/*path", FallbackController, :not_found
  end

  # Other scopes may use custom stacks.
  # scope "/api", ExpensePilotWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:expense_pilot, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ExpensePilotWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
