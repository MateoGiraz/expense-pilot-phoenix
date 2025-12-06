# Audit Service

A microservice for immutable audit logging.

## Features

- Create and view audit logs
- Immutable log records
- Company-based filtering
- User tracking
- Date range filtering
- JSON API responses

## Test Coverage

This project tracks **test coverage** for informational purposes. The CI pipeline **logs coverage but does not fail** based on coverage thresholds - it only fails on actual test failures.

### Running Tests Locally

```bash
# Install dependencies
bundle install

# Setup test database
bin/rails db:test:prepare

# Run tests with coverage
bin/rails test

# View coverage report
open coverage/index.html
```

### Coverage Configuration

- Coverage is measured using SimpleCov
- Configuration is in `.simplecov`
- HTML reports are generated for local viewing
- Coverage is logged in CI but doesn't block deployment

## API Endpoints

### GET /api/v1/audit_logs

List audit logs with optional filters:

- `company_id` (required): Company ID to filter by
- `user_id`: Filter by user ID
- `user_email`: Filter by user email (case insensitive)
- `audit_action`: Filter by action type
- `resource_type`: Filter by resource type
- `start_date`: Filter from date (YYYY-MM-DD)
- `end_date`: Filter to date (YYYY-MM-DD)
- `page`: Page number (default: 1)
- `per_page`: Records per page (default: 50)

### GET /api/v1/audit_logs/:id

Get a specific audit log by ID.

### POST /api/v1/audit_logs

Create a new audit log:

```json
{
  "audit_log": {
    "action": "create",
    "resource_type": "User",
    "resource_id": 123,
    "user_id": 456,
    "company_id": 789,
    "user_email": "user@example.com",
    "data": {
      "additional": "information"
    }
  }
}
```

## CI/CD

The project uses GitHub Actions for CI/CD (located in root `/.github/workflows/ci/audit-service-ci.yml`):

- **Security scanning** with Brakeman
- **Code linting** with RuboCop
- **Test execution** with coverage reporting
- **Coverage logging** (informational only - doesn't block CI)
- **Coverage reporting** on pull requests
- **Failure only on test failures** (not coverage thresholds)

## Development

```bash
# Install dependencies
bundle install

# Setup database
bin/rails db:create db:migrate

# Run the server
bin/rails server

# Run tests
bin/rails test

# Lint code
bin/rubocop

# Security scan
bin/brakeman
```
