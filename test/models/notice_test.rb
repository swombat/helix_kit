require "test_helper"

class NoticeTest < ActiveSupport::TestCase

  test "for_agent returns active system and matching account notices in order" do
    agent = agents(:research_assistant)
    other_agent = agents(:other_account_agent)
    system_notice = create_notice(scope: "system", notice_type: "site_renamed", created_at: 3.minutes.ago)
    account_notice = create_notice(
      scope: "account",
      account: agent.account,
      notice_type: "announcement",
      body: "Shared account news",
      created_at: 2.minutes.ago
    )
    other_account_notice = create_notice(
      scope: "account",
      account: other_agent.account,
      notice_type: "announcement",
      body: "Other account news"
    )
    create_notice(
      scope: "account",
      account: agent.account,
      notice_type: "announcement",
      body: "Expired news",
      expires_at: 1.minute.ago
    )

    assert_equal [ system_notice, account_notice ], Notice.for_agent(agent).to_a
    assert_equal [ system_notice, other_account_notice ], Notice.for_agent(other_agent).to_a
  end

  test "scope and account must agree" do
    system_notice = Notice.new(
      scope: "system",
      account: accounts(:personal_account),
      notice_type: "site_renamed",
      expires_at: 1.day.from_now
    )
    account_notice = Notice.new(
      scope: "account",
      notice_type: "announcement",
      body: "News",
      expires_at: 1.day.from_now
    )

    assert_not system_notice.valid?
    assert_includes system_notice.errors[:account], "must be absent for system notices"
    assert_not account_notice.valid?
    assert_includes account_notice.errors[:account], "must be present for account notices"
  end

  test "notice type must be supported" do
    notice = Notice.new(
      scope: "system",
      notice_type: "surprise",
      expires_at: 1.day.from_now
    )

    assert_not notice.valid?
    assert_includes notice.errors[:notice_type], "is not included in the list"
  end

  test "announcements require a bounded body" do
    notice = Notice.new(
      scope: "system",
      notice_type: "announcement",
      body: "",
      expires_at: 1.day.from_now
    )

    assert_not notice.valid?
    assert_includes notice.errors[:body], "can't be blank"

    notice.body = "x" * 5_001
    assert_not notice.valid?
    assert_includes notice.errors[:body], "is too long (maximum is 5000 characters)"
  end

  private

  def create_notice(**attributes)
    Notice.create!({
      expires_at: 1.day.from_now
    }.merge(attributes))
  end

end
