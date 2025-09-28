require "test_helper"

class SettingTest < ActiveSupport::TestCase

  test "instance returns setting" do
    setting = Setting.instance
    assert_equal setting, Setting.instance
  end

  test "validates site_name presence" do
    setting = Setting.instance
    setting.site_name = ""
    assert_not setting.valid?
  end

  test "validates site_name length" do
    setting = Setting.instance
    setting.site_name = "a" * 101
    assert_not setting.valid?
  end

end
