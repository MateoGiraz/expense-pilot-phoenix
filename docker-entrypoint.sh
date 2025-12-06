#!/bin/bash
set -e

# Run migrations
echo "Running migrations..."
bin/expense_pilot eval "ExpensePilot.Release.migrate"

# Run seeds
echo "Running seeds..."
bin/expense_pilot eval "ExpensePilot.Release.seed"

# Start the Elixir application
echo "Starting application..."
exec bin/expense_pilot start
