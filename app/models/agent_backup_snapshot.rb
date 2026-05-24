class AgentBackupSnapshot < ApplicationRecord

  belongs_to :agent

  validates :restic_snapshot_id, presence: true
  validates :taken_at, presence: true

end
