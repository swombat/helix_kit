class RemovePromptCacheLayoutV2FromAgents < ActiveRecord::Migration[8.1]

  def change
    remove_column :agents, :prompt_cache_layout_v2, :boolean
  end

end
