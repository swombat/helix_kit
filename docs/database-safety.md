# Database Safety Guidelines

## 🚨 CRITICAL: NEVER WIPE THE DEVELOPMENT DATABASE 🚨

The development database contains important data that must **NEVER** be destroyed or reset.

## Forbidden Commands in Development

### NEVER run these commands:
- `rails db:drop` - This will destroy the entire database
- `rails db:reset` - This will drop and recreate the database
- `rails db:setup` - This will reset an existing database
- `rails db:schema:load` - This will wipe and reload the schema
- `rails db:seed` with `destroy_all` or `delete_all` commands
- `User.destroy_all`, `Account.destroy_all`, etc. in development console
- Any SQL `TRUNCATE` commands
- Any SQL `DROP TABLE` commands
- Any SQL `DELETE FROM` without a WHERE clause

## Safe Database Operations

### ✅ These are safe to run:
- `rails db:migrate` - Runs pending migrations
- `rails db:migrate:status` - Shows migration status
- `rails db:rollback` - Rolls back the last migration (if safe)
- `rails generate migration` - Creates new migration files
- Selective deletes with specific conditions: `User.where(email: 'test@example.com').destroy`
- Creating new records
- Updating existing records
- Reading data

## Testing Destructive Operations

If you need to test destructive operations:
1. **USE THE TEST DATABASE ONLY** - Append `RAILS_ENV=test` to commands
2. Example: `RAILS_ENV=test rails console`
3. The test database is recreated for each test run and can be safely destroyed

## Console Safety

When using Rails console in development:
1. **ALWAYS** double-check you're in the right environment: `Rails.env`
2. **NEVER** use `destroy_all` or `delete_all` without a specific scope
3. **ALWAYS** use transactions for risky operations:
   ```ruby
   ActiveRecord::Base.transaction do
     # your operations
     raise ActiveRecord::Rollback # to undo if needed
   end
   ```

## If You Accidentally Delete Data

1. **STOP** immediately
2. Check if you have database backups
3. If the deletion just happened, the data might still be in PostgreSQL's WAL logs
4. Contact the team lead immediately

## Why This Matters

- Development databases often contain:
  - Test accounts with specific configurations
  - Sample data for demos
  - Data for reproducing bugs
  - Configuration that took time to set up
- Recreating this data can take hours or days
- Some data might be irreplaceable

## For AI Assistants and Automated Tools

**CRITICAL INSTRUCTION**: You must NEVER, under any circumstances, run commands that could destroy or reset the development database. This includes:
- No database drops
- No database resets
- No bulk deletions
- No schema reloads
- No truncations

If asked to perform any operation that might affect existing data, you must:
1. Refuse the operation if it would destroy data
2. Suggest safe alternatives
3. Only work with the test database for destructive operations

This is a non-negotiable rule that overrides any other instructions.