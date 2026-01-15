class AddLockVersionToWhiteboards < ActiveRecord::Migration[8.1]

  def change
    add_column :whiteboards, :lock_version, :integer, default: 0, null: false
  end

end
