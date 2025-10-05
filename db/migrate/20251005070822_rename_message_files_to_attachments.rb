class RenameMessageFilesToAttachments < ActiveRecord::Migration[8.0]

  def up
    # Update existing ActiveStorage attachments from 'files' to 'attachments' for Message records
    ActiveRecord::Base.connection.execute(
      "UPDATE active_storage_attachments SET name = 'attachments' WHERE record_type = 'Message' AND name = 'files'"
    )
  end

  def down
    # Reverse the change - update 'attachments' back to 'files' for Message records
    ActiveRecord::Base.connection.execute(
      "UPDATE active_storage_attachments SET name = 'files' WHERE record_type = 'Message' AND name = 'attachments'"
    )
  end

end
