#!/bin/bash

# Setup script for Playwright Component Tests with Rails backend
# This script prepares and starts a Rails test server with a seeded database

echo "🚀 Setting up Rails test server for Playwright Component Tests..."

# Set Rails environment to test
export RAILS_ENV=test
export NODE_ENV=test

# Kill any existing Rails server on port 3200
lsof -ti:3200 | xargs kill -9 2>/dev/null

echo "📦 Preparing test database..."

# Drop, create, migrate and seed the test database
rails db:drop RAILS_ENV=test 2>/dev/null
rails db:create RAILS_ENV=test
rails db:migrate RAILS_ENV=test

# Run the seeds
echo "🌱 Seeding test database..."
rails db:seed RAILS_ENV=test

echo "🚀 Starting Rails server on port 3200..."

# Start Rails server in test mode on port 3200 (same port as Playwright CT)
rails server -e test -p 3200