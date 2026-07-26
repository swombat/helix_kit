class AddAccountToApiKeys < ActiveRecord::Migration[8.1]

  def up
    add_reference :api_keys, :account, foreign_key: true unless column_exists?(:api_keys, :account_id)
    add_index :api_keys, :account_id unless index_exists?(:api_keys, :account_id)
    add_foreign_key :api_keys, :accounts unless foreign_key_exists?(:api_keys, :accounts)

    execute <<~SQL
      UPDATE api_keys
      SET account_id = agents.account_id
      FROM agents
      WHERE api_keys.agent_id = agents.id
        AND api_keys.account_id IS NULL
    SQL

    execute <<~SQL
      UPDATE api_keys
      SET account_id = (
        SELECT memberships.account_id
        FROM memberships
        WHERE memberships.user_id = api_keys.user_id
          AND memberships.confirmed_at IS NOT NULL
        ORDER BY memberships.id
        LIMIT 1
      )
      WHERE api_keys.account_id IS NULL
    SQL

    change_column_null :api_keys, :account_id, false
  end

  def down
    remove_reference :api_keys, :account, foreign_key: true
  end

end
