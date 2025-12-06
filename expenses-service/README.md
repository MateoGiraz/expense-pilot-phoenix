# Expenses Service

This is a Go microservice for managing expenses in the ExpensePilot application.

## Features

- CRUD operations for expenses
- Filter expenses by date range
- Filter expenses by category
- Pagination support
- Company-based data isolation

## API Endpoints

### Expenses

- `GET /api/companies/:company_id/expenses` - List expenses
- `GET /api/companies/:company_id/expenses/:id` - Get expense details
- `POST /api/companies/:company_id/expenses` - Create expense
- `PUT /api/companies/:company_id/expenses/:id` - Update expense
- `DELETE /api/companies/:company_id/expenses/:id` - Delete expense
- `GET /api/companies/:company_id/expenses/by-date` - List expenses by date range

### Query Parameters

- `page` - Page number (default: 1)
- `page_size` - Items per page (default: 10)
- `start_date` - Start date for filtering (format: YYYY-MM-DD)
- `end_date` - End date for filtering (format: YYYY-MM-DD)
- `category_id` - Category ID for filtering

## Setup

1. Install Go 1.21 or later
2. Install PostgreSQL
3. Create a database named `expenses_service_db`
4. Copy `.env.example` to `.env` and update the values
5. Run migrations:
   ```bash
   go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
   migrate -path migrations -database "postgresql://postgres:postgres@localhost:5432/expenses_service_db?sslmode=disable" up
   ```
6. Run the service:
   ```bash
   go run cmd/main.go
   ```

## Development

- The service uses Gin for routing
- PostgreSQL for data storage
- golang-migrate for database migrations

## Integration with Phoenix App

To integrate with the Phoenix app, update the expense-related API calls to point to this service instead of the local database. The service runs on port 4001 by default. 