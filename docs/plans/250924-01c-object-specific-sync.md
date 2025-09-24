# Object-Specific Streaming Sync Implementation Plan

Based on the specification at `/docs/plans/250924-01c-object-specific-sync.md`

## Tasks

- [x] **Add streaming column to messages table**
  - Create a migration to add `streaming:boolean` column with default false and index

- [x] **Update Message model**
  - Add the `stream_content` method that broadcasts updates
  - Add the `stop_streaming` method that sets streaming to false
  - Ensure proper obfuscated_id usage for channel names

- [x] **Update AiResponseJob**
  - Add `ensure` block to stop streaming even on errors
  - Call `message.stream_content(chunk)` for each content update
  - Set streaming to true at start, false at end

- [x] **Write tests**
  - Test the new Message model methods
  - Test that AiResponseJob properly handles streaming

## Implementation Notes
- Keep it SIMPLE - no abstractions, no concerns
- Follow Rails conventions exactly
- Use existing authorization patterns (through associations)
- Use obfuscated_id for security in channel names
- The SyncChannel already supports object-specific subscriptions, no changes needed

## Implementation Summary

Successfully implemented object-specific streaming sync for AI messages with:

1. **Database Schema**: Added `streaming` boolean column to messages table with default false and index
2. **Message Model**: Added `stream_content(chunk)` and `stop_streaming` methods with proper ActionCable broadcasts
3. **AI Response Job**: Updated to use streaming methods with ensure block for error handling
4. **Tests**: Comprehensive test coverage for all new functionality
5. **Channel Support**: Existing SyncChannel already supports Message:#{obfuscated_id} subscriptions

## Files Modified
- `/db/migrate/20250924062904_add_streaming_to_messages.rb` - New migration
- `/app/models/message.rb` - Added streaming methods
- `/app/jobs/ai_response_job.rb` - Updated to use streaming
- `/test/models/message_test.rb` - Added streaming tests
- `/test/jobs/ai_response_job_test.rb` - Updated with streaming tests

## Deviations from Original Plan
None - implemented exactly as specified in the final specification.