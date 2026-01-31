class AgentMemory < ApplicationRecord

  include Broadcastable

  JOURNAL_WINDOW = 1.week
  CORE_TOKEN_BUDGET = 5000

  belongs_to :agent

  broadcasts_to :agent

  enum :memory_type, { journal: 0, core: 1 }

  validates :content, presence: true, length: { maximum: 10_000 }
  validates :memory_type, presence: true

  scope :active_journal, -> { journal.where(created_at: JOURNAL_WINDOW.ago..) }
  scope :for_prompt, -> { where(memory_type: :core).or(active_journal).order(created_at: :asc) }
  scope :recent_first, -> { order(created_at: :desc) }
  scope :constitutional, -> { where(constitutional: true) }

  before_destroy :prevent_constitutional_destruction

  def expired?
    journal? && created_at < JOURNAL_WINDOW.ago
  end

  def token_estimate
    (content.to_s.length / 4.0).ceil
  end

  def as_ledger_entry
    { id:, content:, created_at: created_at.iso8601, tokens: token_estimate, constitutional: constitutional? }
  end

  def audit_refinement(operation, before_content, after_content)
    AuditLog.create!(
      action: "memory_refinement_#{operation}",
      auditable: self,
      account_id: agent.account_id,
      data: { agent_id: agent_id, operation:, before: before_content, after: after_content }
    )
  end

  private

  def prevent_constitutional_destruction
    throw(:abort) if constitutional?
  end

end
