# API Gateway

FastAPI-based API Gateway for Expense Pilot microservices architecture.

## Overview

The API Gateway serves as a single entry point for all client requests and forwards them to the appropriate microservices. It provides:

- **Unified API**: Single endpoint for all services
- **Request routing**: Intelligent forwarding to microservices
- **Health monitoring**: Service health checks and monitoring
- **CORS handling**: Cross-origin resource sharing support
- **Error handling**: Centralized error responses
- **Documentation**: Interactive API docs

## Architecture

```
Client → API Gateway → Microservices
                    ├── Auth Service (Node.js)
                    ├── Expenses Service (Go)
                    ├── Audit Service (Rails)
                    └── Notification Service (Python)
```

## Endpoints

### Health Checks
- `GET /health` - Gateway health check
- `GET /health/services` - All services health status

### Auth Service Routes
- `POST /auth/login` - User authentication
- `POST /auth/validate-token` - Token validation
- `GET|POST|PUT|DELETE /users/*` - User management

### Expenses Service Routes
- `GET|POST|PUT|DELETE /api/companies/{company_id}/expenses` - Expense operations
- `GET /api/companies/{company_id}/expenses/by-date` - Expenses by date range

### Audit Service Routes
- `GET|POST /api/v1/audit/*` - Audit operations

### Notification Service Routes
- `GET|POST /notifications/*` - Notification operations

### Documentation
- `GET /docs` - Interactive API documentation (Swagger)
- `GET /redoc` - ReDoc documentation
- `GET /swagger/auth` - Auth service Swagger docs
- `GET /swagger/expenses` - Expenses service Swagger docs

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Gateway port | `8080` |
| `AUTH_SERVICE_URL` | Auth service URL | `http://auth-service:5439` |
| `EXPENSES_SERVICE_URL` | Expenses service URL | `http://expenses-service:4001` |
| `AUDIT_SERVICE_URL` | Audit service URL | `http://audit-service:3000` |
| `NOTIFICATION_SERVICE_URL` | Notification service URL | `http://notification-service:8000` |

## Development

### Running Locally
```bash
cd api-gateway
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8080 --reload
```

### Docker
```bash
docker build -t expense-pilot-gateway .
docker run -p 8080:8080 expense-pilot-gateway
```

### Docker Compose
```bash
docker compose up api-gateway
```

## Usage Examples

### Authentication
```bash
# Login
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password"}'

# Validate token
curl -X POST http://localhost:8080/auth/validate-token \
  -H "Content-Type: application/json" \
  -d '{"token": "your-jwt-token"}'
```

### Expenses
```bash
# Get expenses for company
curl http://localhost:8080/api/companies/1/expenses

# Create expense
curl -X POST http://localhost:8080/api/companies/1/expenses \
  -H "Content-Type: application/json" \
  -d '{"amount": 100.50, "category_id": 1, "user_id": 1, "date": "2024-01-01"}'
```

### Health Check
```bash
# Gateway health
curl http://localhost:8080/health

# All services health
curl http://localhost:8080/health/services
```

## Features

- **Async/Await**: High performance async request handling
- **Timeout handling**: Configurable request timeouts
- **Error propagation**: Proper HTTP status code forwarding
- **Header forwarding**: Maintains request context
- **Query parameter support**: Full URL parameter forwarding
- **Body forwarding**: Support for POST/PUT request bodies
- **CORS enabled**: Cross-origin request support

## Monitoring

The gateway provides comprehensive health monitoring:

- Service availability checks
- Response time monitoring
- Error tracking and logging
- Status code reporting

Access the monitoring dashboard at: `http://localhost:8080/health/services` 