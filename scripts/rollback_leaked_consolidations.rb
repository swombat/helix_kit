# Rollback leaked post-rollback consolidations from session d16f4d0d
#
# What happened: The refinement session for Chris (Agent 1) was rolled back by
# the circuit breaker at 05:01:24 UTC on 2026-02-16, but the LLM continued
# making consolidation calls afterwards (05:01:42-43). These 7 consolidations
# leaked through because RefinementTool had no @terminated flag.
#
# This script reverses those 7 leaked consolidations:
# - Discards the leaked consolidated memories (3043-3049 in dev)
# - Restores the original source memories that were re-discarded
#
# Usage:
#   DRY_RUN=1 bin/rails runner scripts/rollback_leaked_consolidations.rb  # preview
#   bin/rails runner scripts/rollback_leaked_consolidations.rb             # execute

SESSION_ID = "d16f4d0d-16aa-45ac-be56-02698f2ca12c"
dry_run = ENV["DRY_RUN"].present?

puts dry_run ? "=== DRY RUN ===" : "=== EXECUTING ==="
puts ""

# Find the rollback event to get its timestamp
rollback = AuditLog
  .where(action: "memory_refinement_rollback")
  .where("data->>'session_id' = ?", SESSION_ID)
  .first!
puts "Rollback occurred at: #{rollback.created_at}"

# Find consolidations that happened AFTER the rollback in the same session
leaked = AuditLog
  .where(action: "memory_refinement_consolidate")
  .where("data->>'session_id' = ?", SESSION_ID)
  .where("created_at > ?", rollback.created_at)
  .order(:created_at)

puts "Found #{leaked.count} leaked post-rollback consolidations"
puts ""

restored_count = 0
discarded_count = 0

ActiveRecord::Base.transaction do
  leaked.each do |log|
    data = log.data
    consolidated_id = data.dig("result", "id")
    merged_entries = data["merged"] || []
    merged_ids = merged_entries.map { |m| m["id"] }

    consolidated = AgentMemory.find_by(id: consolidated_id)
    puts "Consolidated memory ##{consolidated_id}:"
    puts "  Content: #{consolidated&.content.to_s[0..80]}..."
    puts "  Currently: #{consolidated&.discarded_at.present? ? 'DISCARDED' : 'ACTIVE'}"
    puts "  Merged from: #{merged_ids.join(', ')}"

    # Discard the leaked consolidated memory
    if consolidated && !consolidated.discarded_at.present?
      if dry_run
        puts "  -> WOULD discard consolidated memory ##{consolidated_id}"
      else
        consolidated.discard!
        puts "  -> Discarded consolidated memory ##{consolidated_id}"
      end
      discarded_count += 1
    end

    # Restore the source memories
    merged_ids.each do |source_id|
      source = AgentMemory.with_discarded.find_by(id: source_id)
      if source&.discarded_at.present?
        if dry_run
          puts "  -> WOULD restore source memory ##{source_id}: #{source.content.to_s[0..60]}..."
        else
          source.undiscard!
          puts "  -> Restored source memory ##{source_id}"
        end
        restored_count += 1
      else
        puts "  -> Source ##{source_id} already active, skipping"
      end
    end
    puts ""
  end

  raise ActiveRecord::Rollback if dry_run
end

agent = Agent.find_by(name: "Chris")
post_mass = agent.core_token_usage if agent

puts "=== SUMMARY ==="
puts "Leaked consolidations reversed: #{leaked.count}"
puts "Consolidated memories discarded: #{discarded_count}"
puts "Source memories restored: #{restored_count}"
puts "Chris core token usage after: #{post_mass}" if post_mass
puts dry_run ? "\nDry run — no changes made. Remove DRY_RUN=1 to execute." : "\nDone."
