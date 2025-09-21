class MigrateExistingUsersToAccounts < ActiveRecord::Migration[8.0]

  def up
    # User.find_each do |user|
    #   next if user.migrated_to_accounts

    #   ActiveRecord::Base.transaction do
    #     # Create personal account
    #     account = Account.create!(
    #       name: "#{user.email_address}'s Account",
    #       account_type: :personal,
    #       created_at: user.created_at
    #     )

    #     # Create account_user with existing confirmation data
    #     AccountUser.create!(
    #       account: account,
    #       user: user,
    #       role: 'owner',
    #       confirmation_token: user.confirmation_token,
    #       confirmation_sent_at: user.confirmation_sent_at,
    #       confirmed_at: user.confirmed_at,
    #       created_at: user.created_at
    #     )

    #     # Set default account
    #     user.update_columns(
    #       default_account_id: account.id,
    #       migrated_to_accounts: true
    #     )
    #   end
    # end
  end

  def down
    # # Restore confirmation fields to users before dropping account tables
    # AccountUser.includes(:user).find_each do |au|
    #   au.user.update_columns(
    #     confirmation_token: au.confirmation_token,
    #     confirmation_sent_at: au.confirmation_sent_at,
    #     confirmed_at: au.confirmed_at
    #   )
    # end

    # User.update_all(default_account_id: nil, migrated_to_accounts: false)
    # AccountUser.destroy_all
    # Account.destroy_all
  end

end
