#!/bin/bash
set -e

echo "🔧 Starting auth service initialization..."

# Extract database connection details from DATABASE_URL
# Format: postgresql://user:password@host:port/database
if [ -z "$DATABASE_URL" ]; then
  echo "❌ DATABASE_URL environment variable is required"
  exit 1
fi

# Parse DATABASE_URL using parameter expansion and sed
DB_HOST=$(echo "$DATABASE_URL" | sed -n 's|.*://[^@]*@\([^:]*\):.*|\1|p')
DB_PORT=$(echo "$DATABASE_URL" | sed -n 's|.*://[^@]*@[^:]*:\([0-9]*\)/.*|\1|p')

if [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ]; then
  echo "❌ Could not parse DATABASE_URL. Expected format: postgresql://user:password@host:port/database"
  exit 1
fi

echo "🔗 Connecting to database at $DB_HOST:$DB_PORT"

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
timeout=60
counter=0

while [ $counter -lt $timeout ]; do
  if nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; then
    echo "✅ Database is ready!"
    break
  fi
  echo "Database is unavailable - sleeping (${counter}/${timeout})"
  sleep 1
  counter=$((counter + 1))
done

if [ $counter -eq $timeout ]; then
  echo "❌ Timeout waiting for database at $DB_HOST:$DB_PORT"
  exit 1
fi

# Run Prisma migrations
echo "🔄 Running Prisma migrations..."
npx prisma migrate deploy

# Generate Prisma client (in case it's not already generated)
echo "🔧 Generating Prisma client..."
npx prisma generate

echo "🚀 Starting auth service..."
exec npm start 