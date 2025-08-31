class AddInvitationFieldsToAccountUsers < ActiveRecord::Migration[8.0]

  def change
    add_column :account_users, :invitation_accepted_at, :datetime
    add_index :account_users, :invitation_accepted_at
  end

end
