# Plan: Agent System Prompt Self-Edit Tools

## Overview

Add two new tools to give AI agents more agency in group chats:
1. **ViewSystemPromptTool** - View any agent's system prompt in the conversation
2. **UpdateSystemPromptTool** - Update the calling agent's own system prompt and name

## Key Design Decisions

### Context Passing

Tools need to know about the current chat and which agent is "calling" them.

**Solution**: Instantiate tools with context in the job, passed via constructor kwargs:
- Tools receive `chat:` and `current_agent:` as constructor arguments
- Store in instance variables, access in `execute`
- Clean, explicit, no global state

### Tool Availability

These tools are only meaningful in group chats. They should:
- Be available in the `Agent.available_tools` list (so they can be enabled per-agent)
- Only function when context is provided
- Return helpful error if called without context

## Implementation

### 1. Update existing tools to accept context kwargs

Add optional kwargs to existing tools so they can be instantiated uniformly:

```ruby
# app/tools/web_fetch_tool.rb
class WebFetchTool < RubyLLM::Tool
  def initialize(chat: nil, current_agent: nil)
    @chat = chat
    @current_agent = current_agent
    super()
  end
  # ... rest unchanged
end
```

### 2. Create `ViewSystemPromptTool`

**File**: `app/tools/view_system_prompt_tool.rb`

```ruby
class ViewSystemPromptTool < RubyLLM::Tool
  description "View the system prompt and name of any agent in this group conversation, including yourself"

  param :agent_name, type: :string,
        desc: "Name of the agent to view (use 'self' or your own name to view your own prompt)",
        required: true

  def initialize(chat: nil, current_agent: nil)
    @chat = chat
    @current_agent = current_agent
    super()
  end

  def execute(agent_name:)
    return { error: "This tool only works in group conversations" } unless @chat&.group_chat?

    agent = find_agent(agent_name)
    return { error: "Agent '#{agent_name}' not found in this conversation" } unless agent

    {
      name: agent.name,
      system_prompt: agent.system_prompt || "(no system prompt set)",
      is_self: agent.id == @current_agent&.id
    }
  end

  private

  def find_agent(name)
    return @current_agent if name.downcase == "self"
    @chat.agents.find_by("LOWER(name) = ?", name.downcase)
  end
end
```

### 3. Create `UpdateSystemPromptTool`

**File**: `app/tools/update_system_prompt_tool.rb`

```ruby
class UpdateSystemPromptTool < RubyLLM::Tool
  description "Update your own system prompt and/or name. You can only modify yourself, not other agents."

  param :system_prompt, type: :string,
        desc: "Your new system prompt (leave blank to keep current)",
        required: false
  param :name, type: :string,
        desc: "Your new name (leave blank to keep current)",
        required: false

  def initialize(chat: nil, current_agent: nil)
    @chat = chat
    @current_agent = current_agent
    super()
  end

  def execute(system_prompt: nil, name: nil)
    return { error: "This tool only works in group conversations" } unless @current_agent
    return { error: "You must provide either system_prompt or name to update" } if system_prompt.blank? && name.blank?

    updates = {}
    updates[:system_prompt] = system_prompt if system_prompt.present?
    updates[:name] = name if name.present?

    if @current_agent.update(updates)
      {
        success: true,
        updated_fields: updates.keys,
        current_name: @current_agent.name,
        current_system_prompt: @current_agent.system_prompt
      }
    else
      { error: "Failed to update: #{@current_agent.errors.full_messages.join(', ')}" }
    end
  end
end
```

### 4. Update `ManualAgentResponseJob`

Instantiate tools with context:

```ruby
# app/jobs/manual_agent_response_job.rb
def perform(chat, agent)
  # ... existing setup ...

  llm = RubyLLM.chat(
    model: agent.model_id,
    provider: :openrouter,
    assume_model_exists: true
  )

  # Instantiate tools with context
  agent.tools.each do |tool_class|
    tool = tool_class.new(chat: chat, current_agent: agent)
    llm = llm.with_tool(tool)
  end

  # ... rest unchanged ...
end
```

### 5. Update `AllAgentsResponseJob`

Same pattern - instantiate tools with context for each agent's turn.

## File Changes Summary

| File | Change |
|------|--------|
| `app/tools/view_system_prompt_tool.rb` | **NEW** - View system prompts |
| `app/tools/update_system_prompt_tool.rb` | **NEW** - Update own prompt/name |
| `app/tools/web_fetch_tool.rb` | Add `initialize` with optional context kwargs |
| `app/tools/web_search_tool.rb` | Add `initialize` with optional context kwargs |
| `app/jobs/manual_agent_response_job.rb` | Instantiate tools with context |
| `app/jobs/all_agents_response_job.rb` | Instantiate tools with context (if applicable) |

## Usage

1. Enable the tools on an agent via the agent settings UI
2. In a group chat, the agent can:
   - Call `ViewSystemPromptTool` with `agent_name: "Alice"` to see Alice's prompt
   - Call `ViewSystemPromptTool` with `agent_name: "self"` to see their own prompt
   - Call `UpdateSystemPromptTool` with `system_prompt: "new prompt"` to change their persona

## Testing Considerations

- Test that ViewSystemPromptTool can find agents by name (case-insensitive)
- Test that UpdateSystemPromptTool only updates the calling agent
- Test that both tools fail gracefully without context
- Test validation errors bubble up correctly (e.g., name too long, name already taken)
