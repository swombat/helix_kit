class AddAccountToApiKeys < ActiveRecord::Migration[8.1]
  def change
    # Nullable + additive: existing user-scoped keys keep resolving to the
    # user's first account; a key with an account_id resolves to that account.
    # This is the per-account key scoping the API auth layer flagged as a TODO.
    add_reference :api_keys, :account, null: true, foreign_key: true
  end
end
