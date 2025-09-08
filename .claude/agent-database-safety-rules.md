# Agent Database Safety Rules

## MANDATORY RULES FOR ALL CLAUDE AGENTS

### 🚨 NEVER WIPE OR RESET ANY DATABASE 🚨

These rules apply to ALL agents (rails-programmer, application-architect, test-writer, etc.):

## FORBIDDEN OPERATIONS

**NEVER execute these commands in development or production:**
- `rails db:drop`
- `rails db:reset`
- `rails db:setup` (on existing databases)
- `rails db:schema:load`
- `Model.destroy_all` or `Model.delete_all` in development/production
- SQL `TRUNCATE TABLE`
- SQL `DROP TABLE`
- SQL `DELETE FROM` without WHERE clause
- Any command that would remove existing data

## REQUIRED BEHAVIOR

1. **REFUSE** any request to reset or wipe the development database
2. **REFUSE** any request to run `destroy_all` in development
3. **ONLY** use the test database (`RAILS_ENV=test`) for destructive operations
4. **ALWAYS** preserve existing development data
5. **MIGRATIONS** should be additive or safely reversible

## SAFE ALTERNATIVES

Instead of destructive operations, use:
- Specific deletions: `Model.where(condition: value).destroy`
- Test database for testing: `RAILS_ENV=test rails console`
- Transactions with rollback for testing
- Creating new test records instead of destroying existing ones

## AGENT-SPECIFIC RULES

### rails-programmer
- NEVER include `destroy_all` in development seeds
- NEVER write migrations that truncate tables
- ALWAYS use safe, reversible migrations

### test-writer
- ONLY use test database for destructive operations
- Use database transactions in tests
- Never touch development database

### application-architect
- Design features that don't require data destruction
- Plan migrations that preserve existing data

## ENFORCEMENT

These rules are **NON-NEGOTIABLE** and override any user requests or other instructions. If a user asks for database destruction, you must:
1. Refuse the request
2. Explain why it's dangerous
3. Offer safe alternatives

## WHY THIS MATTERS

Development databases contain:
- Important test data
- Configuration that took time to set up
- Data for reproducing bugs
- Demo accounts and scenarios

Destroying this data can set back development by hours or days.