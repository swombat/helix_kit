class AddAudioSourceToMessages < ActiveRecord::Migration[8.1]

  def change
    add_column :messages, :audio_source, :boolean, default: false, null: false
  end

end
