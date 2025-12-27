class AgentMemory < ApplicationRecord

  include Broadcastable

  JOURNAL_WINDOW = 1.week

  belongs_to :agent

  broadcasts_to :agent

  enum :memory_type, { journal: 0, core: 1 }

  validates :content, presence: true, length: { maximum: 10_000 }
  validates :memory_type, presence: true

  scope :active_journal, -> { journal.where(created_at: JOURNAL_WINDOW.ago..) }
  scope :for_prompt, -> { where(memory_type: :core).or(active_journal).order(created_at: :asc) }
  scope :recent_first, -> { order(created_at: :desc) }

  def expired?
    journal? && created_at < JOURNAL_WINDOW.ago
  end

end
