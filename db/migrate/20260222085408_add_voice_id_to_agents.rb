class AddVoiceIdToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :voice_id, :string
  end
end
