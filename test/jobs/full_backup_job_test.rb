require "test_helper"

class FullBackupJobTest < ActiveJob::TestCase

  setup do
    @agent_a = agents(:research_assistant)
    @agent_b = agents(:code_reviewer)
    [ @agent_a, @agent_b ].each do |agent|
      agent.update_columns(runtime: "external", uuid: SecureRandom.uuid)
    end
    @dumped = false
    @dump_stub = -> { @dumped = true }
  end

  test "nightly run backs up remaining agents and still dumps the database when one agent fails" do
    attempted = []
    backup_stub = ->(agent_id, force:) do
      attempted << agent_id
      raise "restic backup failed" if agent_id == @agent_a.id
    end

    Backup::AgentResticJob.stub(:perform_now, backup_stub) do
      DatabaseBackupJob.stub(:perform_now, @dump_stub) do
        FullBackupJob.perform_now
      end
    end

    assert_includes attempted, @agent_a.id
    assert_includes attempted, @agent_b.id
    assert @dumped, "database dump should still run after an agent failure in nightly mode"
  end

  test "fail_fast run aborts before the database dump when an agent backup fails" do
    backup_stub = ->(agent_id, force:) do
      raise "restic backup failed" if agent_id == @agent_a.id
    end

    Backup::AgentResticJob.stub(:perform_now, backup_stub) do
      DatabaseBackupJob.stub(:perform_now, @dump_stub) do
        assert_raises(RuntimeError) { FullBackupJob.perform_now(fail_fast: true) }
      end
    end

    refute @dumped, "database dump must not run after an agent failure in fail_fast mode"
  end

  test "fail_fast run forces agent backups; nightly run respects the backups_enabled gate" do
    forced_flags = []
    backup_stub = ->(_agent_id, force:) { forced_flags << force }

    Backup::AgentResticJob.stub(:perform_now, backup_stub) do
      DatabaseBackupJob.stub(:perform_now, @dump_stub) do
        FullBackupJob.perform_now(fail_fast: true)
        FullBackupJob.perform_now
      end
    end

    assert_equal [ true, true, false, false ], forced_flags
  end

  test "skips agents without a uuid and non-hosted agents" do
    @agent_b.update_columns(uuid: nil)
    attempted = []
    backup_stub = ->(agent_id, force:) { attempted << agent_id }

    Backup::AgentResticJob.stub(:perform_now, backup_stub) do
      DatabaseBackupJob.stub(:perform_now, @dump_stub) do
        FullBackupJob.perform_now
      end
    end

    assert_equal [ @agent_a.id ], attempted
    assert @dumped
  end

end
