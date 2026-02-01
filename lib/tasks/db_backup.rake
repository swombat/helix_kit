require "aws-sdk-s3"

module DbBackupHelpers

  module_function

  def ensure_not_production!
    if Rails.env.production?
      abort "ERROR: This task cannot be run in the production environment!"
    end
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      access_key_id: credentials[:access_key_id],
      secret_access_key: credentials[:secret_access_key],
      region: credentials[:postgres_bucket_region] || credentials[:s3_region]
    )
  end

  def bucket_name
    credentials[:postgres_bucket] || abort("postgres_bucket not configured in credentials")
  end

  def credentials
    Rails.application.credentials.aws
  end

  def latest_backup_key
    response = s3_client.list_objects_v2(bucket: bucket_name)
    response.contents
      .map(&:key)
      .select { |k| k.end_with?(".sql.gz") }
      .sort
      .last
  end

  def reset_user_passwords!
    puts "Resetting all user passwords to 'password'..."
    User.find_each do |user|
      user.update_column(:password_digest, BCrypt::Password.create("password"))
      puts "  Reset password for #{user.email_address}"
    end
    puts "All passwords reset to 'password'"
  end

  def create_test_agents!
    nexus_account_obfuscated_id = "PNvAYr"
    nexus_account_id = Account.decode_id(nexus_account_obfuscated_id)
    nexus_account = Account.find_by(id: nexus_account_id)

    unless nexus_account
      puts "Warning: Nexus account (#{nexus_account_obfuscated_id}) not found. Skipping test agent creation."
      return
    end

    puts "Creating test agents in #{nexus_account.name} account..."

    # GPT Test Agent
    gpt_agent = nexus_account.agents.find_or_initialize_by(name: "GPT Test Agent")
    gpt_agent.assign_attributes(
      system_prompt: "You are a test agent for GPT models. Your purpose is to help with testing and development.",
      model_id: "openai/gpt-5-mini",
      active: true
    )
    if gpt_agent.save
      puts "  Created/updated GPT Test Agent (#{gpt_agent.model_id})"
    else
      puts "  Failed to create GPT Test Agent: #{gpt_agent.errors.full_messages.join(', ')}"
    end

    # Claude Test Agent
    claude_agent = nexus_account.agents.find_or_initialize_by(name: "Claude Test Agent")
    claude_agent.assign_attributes(
      system_prompt: "You are a test agent for Claude models. Your purpose is to help with testing and development.",
      model_id: "anthropic/claude-sonnet-4.5",
      active: true
    )
    if claude_agent.save
      puts "  Created/updated Claude Test Agent (#{claude_agent.model_id})"
    else
      puts "  Failed to create Claude Test Agent: #{claude_agent.errors.full_messages.join(', ')}"
    end

    puts "Test agents created."
  end

  def download_path
    Rails.root.join("db", "backups")
  end

end

namespace :db_backup do
  include DbBackupHelpers

  desc "Show the timestamp of the latest database backup"
  task latest: :environment do
    latest = DbBackupHelpers.latest_backup_key
    if latest
      # Extract timestamp from filename like: helix_kit_production_2026-01-10_20-06-56.sql.gz
      if latest.match(/(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})/)
        timestamp_str = $1
        date_part, time_part = timestamp_str.split("_")
        formatted_time = time_part.tr("-", ":")
        puts "Latest backup: #{latest}"
        puts "Timestamp: #{date_part} at #{formatted_time}"
      else
        puts "Latest backup: #{latest}"
      end
    else
      puts "No backups found in bucket."
    end
  end

  desc "Download the latest database backup from S3"
  task download: :environment do
    DbBackupHelpers.ensure_not_production!

    latest = DbBackupHelpers.latest_backup_key
    abort "No backups found in bucket." unless latest

    FileUtils.mkdir_p(DbBackupHelpers.download_path)

    local_file = DbBackupHelpers.download_path.join(File.basename(latest))

    puts "Downloading #{latest}..."
    DbBackupHelpers.s3_client.get_object(
      bucket: DbBackupHelpers.bucket_name,
      key: latest,
      response_target: local_file.to_s
    )
    puts "Downloaded to #{local_file}"

    # Decompress
    sql_file = local_file.to_s.sub(/\.gz$/, "")
    puts "Decompressing to #{sql_file}..."
    system("gunzip -f #{local_file}")
    puts "Done. SQL file at: #{sql_file}"
  end

  desc "Restore the latest downloaded backup (overwrites local dev database!)"
  task restore: :environment do
    DbBackupHelpers.ensure_not_production!

    latest_sql = Dir["#{DbBackupHelpers.download_path}/*.sql"].max_by { |f| File.mtime(f) }

    abort "No SQL file found in #{DbBackupHelpers.download_path}. Run `rake db_backup:download` first." unless latest_sql

    db_config = ActiveRecord::Base.connection_db_config.configuration_hash
    dbname = db_config[:database]
    host = db_config[:host] || "localhost"
    username = db_config[:username]
    password = db_config[:password]

    puts "Restoring #{latest_sql} to #{dbname}..."
    puts "WARNING: This will DROP and recreate your local development database!"
    print "Continue? (y/N): "
    response = $stdin.gets.chomp
    abort "Aborted." unless response.downcase == "y"

    env = password ? { "PGPASSWORD" => password } : {}

    # Disconnect all connections and drop the database
    puts "Dropping database #{dbname}..."
    ActiveRecord::Base.connection.disconnect!

    drop_cmd = [ "dropdb" ]
    drop_cmd.push("-h", host) if host
    drop_cmd.push("-U", username) if username
    drop_cmd.push("--if-exists", dbname)
    system(env, *drop_cmd)

    # Create empty database
    puts "Creating database #{dbname}..."
    create_cmd = [ "createdb" ]
    create_cmd.push("-h", host) if host
    create_cmd.push("-U", username) if username
    create_cmd.push(dbname)
    unless system(env, *create_cmd)
      abort "Failed to create database!"
    end

    # Restore from backup
    puts "Restoring from backup..."
    restore_cmd = [ "psql", "-q" ]  # -q for quiet mode
    restore_cmd.push("-h", host) if host
    restore_cmd.push("-U", username) if username
    restore_cmd.push("-d", dbname)
    restore_cmd.push("-f", latest_sql)

    puts "Running: #{restore_cmd.join(' ')}"
    success = system(env, *restore_cmd)

    # Reconnect
    ActiveRecord::Base.establish_connection

    if success
      puts "Database restored successfully."
      DbBackupHelpers.reset_user_passwords!
      DbBackupHelpers.create_test_agents!
    else
      abort "Database restoration failed!"
    end
  end

  desc "Download and restore the latest backup (full refresh)"
  task refresh: [ :download, :restore ] do
    DbBackupHelpers.ensure_not_production!
    puts "Database refresh completed."
  end

  desc "Trigger a database backup on production via Kamal"
  task :perform do
    puts "Triggering database backup on production..."
    system('kamal app exec -r web "bin/rails runner \'DatabaseBackupJob.perform_now\'"')
  end

  desc "Create test agents in the Nexus account"
  task create_test_agents: :environment do
    DbBackupHelpers.ensure_not_production!
    DbBackupHelpers.create_test_agents!
  end
end
