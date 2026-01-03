# frozen_string_literal: true

class AddThinkingSignatureToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :thinking_signature, :text
  end
end
