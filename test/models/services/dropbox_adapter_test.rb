require "test_helper"

class Services::DropboxAdapterTest < ActiveSupport::TestCase

  test "uses Dropbox app_key as the OAuth client id" do
    credentials = Object.new
    credentials.define_singleton_method(:dig) do |*keys|
      keys == [ :dropbox, :app_key ] ? "dropbox-app-key" : nil
    end

    Rails.application.stub(:credentials, credentials) do
      adapter = Services::Definition.fetch("dropbox").adapter
      assert_equal "dropbox-app-key", adapter.send(:client_id)
    end
  end

end
