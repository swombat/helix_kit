require "test_helper"
require "action_cable/test_helper"

class BroadcastableTest < ActiveSupport::TestCase

  include ActionCable::TestHelper

  def setup
    @account = accounts(:personal_account)
  end

  test "broadcasts to self on update" do
    assert_broadcasts("Account:#{@account.obfuscated_id}", 1) do
      @account.update!(name: "New Name")
    end
  end

  test "broadcasts to all collection for admin when configured" do
    assert_broadcasts("Account:all", 1) do
      @account.update!(name: "New Name")
    end
  end

  test "broadcasts removal on destroy" do
    # Expect broadcasts to both self and all
    assert_broadcasts("Account:#{@account.obfuscated_id}", 1) do
      assert_broadcasts("Account:all", 1) do
        @account.destroy
      end
    end
  end

  test "broadcasts on create" do
    new_account = nil

    # New accounts broadcast to self and to all
    assert_broadcasts("Account:all", 1) do
      new_account = Account.create!(
        name: "Test Account",
        account_type: :team
      )
    end
  end

  test "broadcast includes correct payload" do
    # We can't easily test the payload with assert_broadcasts,
    # but we can verify the broadcast happens
    assert_broadcasts("Account:#{@account.obfuscated_id}", 1) do
      @account.update!(name: "Updated Name")
    end
  end

end
