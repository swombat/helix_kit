class RenamePromptAndWebTools < ActiveRecord::Migration[8.0]

  def up
    Agent.find_each do |agent|
      next if agent.enabled_tools.blank?

      original_tools = agent.enabled_tools.dup
      new_tools = original_tools.map do |tool|
        case tool
        when "ViewSystemPromptTool", "UpdateSystemPromptTool"
          "SelfAuthoringTool"
        when "WebSearchTool", "WebFetchTool"
          "WebTool"
        else
          tool
        end
      end.uniq

      if new_tools != original_tools
        agent.update_column(:enabled_tools, new_tools)
      end
    end
  end

  def down
    Agent.find_each do |agent|
      next if agent.enabled_tools.blank?

      original_tools = agent.enabled_tools.dup
      new_tools = original_tools.flat_map do |tool|
        case tool
        when "SelfAuthoringTool"
          %w[ViewSystemPromptTool UpdateSystemPromptTool]
        when "WebTool"
          %w[WebSearchTool WebFetchTool]
        else
          tool
        end
      end.uniq

      if new_tools != original_tools
        agent.update_column(:enabled_tools, new_tools)
      end
    end
  end

end
