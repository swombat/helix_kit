class CreateProfiles < ActiveRecord::Migration[8.0]

  def change
    create_table :profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :first_name
      t.string :last_name
      t.string :theme, default: "system"
      t.string :timezone
      t.jsonb :preferences, default: {}

      t.timestamps
    end

    # Migrate existing user data to profiles
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO profiles (user_id, first_name, last_name, theme, timezone, preferences, created_at, updated_at)
          SELECT id, first_name, last_name,#{' '}
                 COALESCE(preferences->>'theme', 'system'),#{' '}
                 timezone,#{' '}
                 COALESCE(preferences, '{}'),
                 created_at, updated_at
          FROM users
        SQL
      end
    end

    # Remove columns from users table
    remove_column :users, :first_name, :string
    remove_column :users, :last_name, :string
    remove_column :users, :timezone, :string
    remove_column :users, :preferences, :jsonb
  end

end
