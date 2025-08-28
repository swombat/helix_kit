# Development Commands

## Essential Commands

### Starting Development
```bash
bin/dev                  # Start Rails server + Vite (recommended)
rails server            # Start Rails server only (port 3000)
bin/vite dev            # Start Vite dev server only
```

### Database Commands
```bash
# Setup
rails db:create         # Create development and test databases
rails db:migrate        # Run pending migrations
rails db:seed           # Load seed data
rails db:setup          # Create, migrate, and seed
rails db:prepare        # Create (if needed), migrate, and seed

# Management
rails db:rollback       # Rollback last migration
rails db:rollback STEP=3  # Rollback 3 migrations
rails db:drop           # Drop databases
rails db:reset          # Drop, create, migrate, seed

# Schema
rails db:schema:load    # Load schema (faster than migrations)
rails db:schema:dump    # Export current schema
```

### Testing Commands

#### ⚠️ REQUIRED Before Committing Changes:
```bash
# These MUST both pass before any commit:
rails test  # Run Rails backend tests
npm test    # Run Playwright tests (REAL backend - NO mocking!)
```

#### Rails Tests
```bash
rails test              # Run all tests except system tests
rails test:all          # Run all tests including system tests
rails test:db           # Reset DB and run tests
rails test test/models  # Run specific directory
rails test test/models/user_test.rb  # Run specific file
rails test test/models/user_test.rb:15  # Run test at line 15

# System tests
rails test:system       # Run system tests with browser
HEADLESS=true rails test:system  # Run headlessly
```

#### Playwright Component Tests
```bash
npm test        # Run all tests with REAL Rails backend (auto setup)
npm run test:ui # Open Playwright UI for debugging

# NEVER create mocked backend tests - the user will be VERY UNHAPPY!
```

### Code Quality
```bash
# Ruby linting
bin/rubocop             # Run linter
bin/rubocop -a          # Auto-fix safe issues
bin/rubocop -A          # Auto-fix all issues
bin/rubocop app/models  # Lint specific directory

# Security scanning
bin/brakeman            # Security vulnerability scan
bin/brakeman -A         # Run all checks
bin/brakeman -w3        # Only show high confidence warnings
```

### Dependency Management
```bash
# Ruby dependencies
bundle install          # Install gems from Gemfile
bundle update           # Update all gems
bundle update rails     # Update specific gem
bundle outdated         # Show outdated gems
bundle exec [command]   # Run command with bundle context

# JavaScript dependencies  
npm install             # Install from package.json
npm update              # Update packages
npm outdated            # Show outdated packages
npm run [script]        # Run package.json script
```

## Rails Console Commands

### Starting Console
```bash
rails console           # Start console (development)
rails c                 # Shorthand
rails console production  # Production console
rails console --sandbox # Rollback changes on exit
```

### Useful Console Commands
```ruby
# Reload code changes
reload!

# Database queries
User.all
User.find(1)
User.where(email: "test@example.com")

# Create records
User.create!(email: "test@example.com", password: "password")

# Update records
user = User.first
user.update!(name: "New Name")

# Delete records
User.find(1).destroy
User.destroy_all

# Run migrations
ActiveRecord::Migration.run(:up, 20250328233853)

# Check routes
Rails.application.routes.url_helpers.root_path
app.root_url
```

## Rails Generators

### Model & Migration
```bash
rails generate model User email:string name:string
rails generate migration AddAgeToUsers age:integer
rails destroy model User  # Remove generated files
```

### Controller
```bash
rails generate controller Pages home about
rails generate controller Admin::Users index show
```

### Scaffold (Full CRUD)
```bash
rails generate scaffold Post title:string body:text published:boolean
```

### Other Generators
```bash
rails generate mailer UserMailer welcome
rails generate job ProcessPayment
rails generate channel ChatRoom
```

## Asset Management

### Vite Commands
```bash
bin/vite dev            # Start dev server
bin/vite build          # Build for production
bin/vite preview        # Preview production build
```

### Asset Precompilation
```bash
rails assets:precompile # Compile assets for production
rails assets:clean      # Remove old assets
rails assets:clobber    # Remove all assets
```

## Background Jobs (Solid Queue)

### Managing Jobs
```bash
# Start worker
rails solid_queue:start

# Clear all jobs
rails solid_queue:clear

# View job status (in console)
SolidQueue::Job.all
SolidQueue::Job.pending
SolidQueue::Job.failed
```

## Deployment Commands

### Kamal Deployment
```bash
bin/kamal setup         # Initial server setup
bin/kamal deploy        # Deploy application
bin/kamal rollback      # Rollback to previous version
bin/kamal logs          # View production logs
bin/kamal console       # Production Rails console
```

### Database in Production
```bash
RAILS_ENV=production rails db:create
RAILS_ENV=production rails db:migrate
RAILS_ENV=production rails db:seed
```

## Debugging Commands

### Rails Logs
```bash
tail -f log/development.log  # Watch development logs
rails log:clear         # Clear log files
```

### Rails Routes
```bash
rails routes            # Show all routes
rails routes -g user    # Grep for 'user' routes
rails routes -c users   # Routes for UsersController
rails routes --expanded # Detailed route info
```

### Rails Stats
```bash
rails stats             # Code statistics
rails notes             # Show TODO/FIXME notes
rails about             # Environment info
```

## Performance & Optimization

### Database Tasks
```bash
rails db:analyze        # Update DB statistics
rails db:optimize       # Optimize DB tables
```

### Cache Management
```bash
rails cache:clear       # Clear Rails cache
rails tmp:clear         # Clear temp files
rails tmp:cache:clear   # Clear cache files
```

### Benchmarking
```bash
rails runner 'puts Benchmark.measure { 1000.times { User.first } }'
rails profiler 'User.first' --runs 1000
```

## Environment Management

### Environment Variables
```bash
# View current environment
rails runner "puts Rails.env"
echo $RAILS_ENV

# Run commands in specific environment
RAILS_ENV=test rails console
RAILS_ENV=production rails db:migrate
```

### Credentials
```bash
rails credentials:edit  # Edit encrypted credentials
rails credentials:show  # Show decrypted credentials
EDITOR=vim rails credentials:edit  # Use specific editor
```

## Useful Shortcuts & Tips

### Command Aliases
```bash
# Common short forms
rails c   # console
rails s   # server
rails g   # generate
rails d   # destroy
rails t   # test

# Bundle exec shortcuts
be rails c  # If you alias be="bundle exec"
```

### Useful Shell Commands
```bash
# Find Ruby files with pattern
grep -r "def authenticate" app/

# Count lines of code
find app -name "*.rb" | xargs wc -l

# Watch file changes
ls app/**/*.rb | entr -c rails test

# Check port usage
lsof -i :3000  # What's using port 3000
```

## Troubleshooting Commands

### Reset Everything
```bash
# Nuclear option - reset everything
rails db:drop
rails db:create
rails db:migrate
rails db:seed
rails tmp:clear
rails assets:clobber
bundle install
npm install
```

### Fix Common Issues
```bash
# Spring issues
spring stop
spring start

# Permission issues
chmod +x bin/*

# Clear caches
rails tmp:clear
rails cache:clear

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install
bundle install

# Reset test database
RAILS_ENV=test rails db:reset
```