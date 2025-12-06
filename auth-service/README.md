# Authentication & Authorization Microservice

A standalone Express.js microservice for handling authentication and authorization using Prisma ORM with PostgreSQL.

## Features

- User authentication with JWT tokens
- Password hashing with bcrypt
- User invitation system
- Role-based access control
- Rate limiting
- Input validation
- Security middleware (helmet, cors)

## Tech Stack

- **Express.js** - Web framework
- **Prisma** - Database ORM
- **PostgreSQL** - Database
- **JWT** - Authentication tokens
- **bcrypt** - Password hashing
- **express-validator** - Input validation

## Setup

### Prerequisites

- Node.js (v16 or higher)
- PostgreSQL database
- npm or yarn

### Installation

1. Install dependencies:
```bash
npm install
```

2. Set up environment variables:
```bash
cp env.example .env
```

Edit `.env` with your database URL and JWT secret:
```
DATABASE_URL="postgresql://username:password@localhost:5432/auth_db"
JWT_SECRET="your-super-secret-jwt-key"
PORT=3001
NODE_ENV=development
```

3. Generate Prisma client and run migrations:
```bash
npm run prisma:generate
npm run prisma:migrate
```

4. Start the development server:
```bash
npm run dev
```

The service will be running on `http://localhost:3001`

## API Endpoints

### Authentication
- `POST /auth/login` - Authenticate user and get JWT token

### Health Check
- `GET /health` - Service health check

### User Management (Minimal)
- `POST /users` - Create user (used by invitation system)
- `POST /users/create-superadmin` - Create superadmin user
- `PUT /users/:id/password` - Update user password

### Request/Response Examples

#### POST /auth/login
```json
// Request
{
  "email": "user@example.com",
  "password": "password123"
}

// Response
{
  "token": "jwt_token_here",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "role": "member",
    "companyId": 1,
    "invited": false
  },
  "message": "Login successful"
}
```

#### POST /users/create-superadmin
```json
// Request
{
  "email": "admin@example.com",
  "password": "password123"
}

// Response
{
  "user": {
    "id": 1,
    "email": "admin@example.com",
    "role": "superadmin",
    "companyId": null,
    "invited": false,
    "createdAt": "2024-01-01T00:00:00.000Z"
  },
  "message": "Superadmin created successfully"
}
```

#### POST /users
```json
// Request
{
  "email": "newuser@example.com",
  "password": "temp_password",
  "role": "member",
  "companyId": 1,
  "invited": true,
  "invitationToken": "invitation_token"
}

// Response
{
  "user": {
    "id": 2,
    "email": "newuser@example.com",
    "role": "member",
    "companyId": 1,
    "invited": true,
    "createdAt": "2024-01-01T00:00:00.000Z"
  },
  "message": "User created successfully"
}
```

#### PUT /users/:id/password
```json
// Request
{
  "password": "new_password_here"
}

// Response
{
  "message": "Password updated successfully"
}
```

## Database Schema

```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR UNIQUE NOT NULL,
  password_hash VARCHAR NOT NULL,
  role VARCHAR DEFAULT 'member',
  company_id INTEGER,
  invited BOOLEAN DEFAULT false,
  invitation_token VARCHAR,
  invitation_accepted_at TIMESTAMP,
  invitation_sent_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

## User Roles

- `member` - Regular user with basic permissions
- `superadmin` - Administrator with elevated permissions

## JWT Token Structure

```json
{
  "userId": 1,
  "email": "user@example.com",
  "role": "member",
  "companyId": 1,
  "iat": 1234567890,
  "exp": 1234654290
}
```

## Error Responses

All error responses follow this format:
```json
{
  "error": "Error message",
  "details": "Additional details (optional)"
}
```

Common HTTP status codes:
- `400` - Bad Request (validation errors)
- `401` - Unauthorized (invalid credentials/token)
- `404` - Not Found (user/resource not found)
- `409` - Conflict (user already exists)
- `429` - Too Many Requests (rate limit exceeded)
- `500` - Internal Server Error

## Development

### Scripts

- `npm start` - Start production server
- `npm run dev` - Start development server with nodemon
- `npm run prisma:generate` - Generate Prisma client
- `npm run prisma:migrate` - Run database migrations
- `npm run prisma:reset` - Reset database
- `npm run prisma:studio` - Open Prisma Studio

### Environment Variables

- `DATABASE_URL` - PostgreSQL connection string
- `JWT_SECRET` - Secret key for JWT signing
- `PORT` - Server port (default: 3001)
- `NODE_ENV` - Environment (development/production)

## Security Features

- Rate limiting (100 requests per 15 minutes per IP)
- Helmet.js for security headers
- CORS protection
- Input validation and sanitization
- Password hashing with bcrypt (12 rounds)
- JWT token expiration (24 hours)

## Production Deployment

1. Set `NODE_ENV=production`
2. Use a strong `JWT_SECRET`
3. Configure proper database security
4. Set up SSL/TLS
5. Consider using a reverse proxy (nginx)
6. Monitor logs and metrics

## Integration with Main App

The main Elixir/Phoenix app should make HTTP requests to this service for all authentication-related operations. Replace direct database calls with HTTP client calls to the appropriate endpoints. 