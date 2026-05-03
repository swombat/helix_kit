module Agent::Predecessor

  extend ActiveSupport::Concern

  PREDECESSOR_COPIED_ATTRIBUTES = %w[
    account_id active colour enabled_tools icon last_refinement_at
    memory_reflection_prompt model_id refinement_prompt refinement_threshold
    reflection_prompt summary_prompt system_prompt thinking_budget
    thinking_enabled voice_id
  ].freeze

  included do
    const_set(:PREDECESSOR_COPIED_ATTRIBUTES, PREDECESSOR_COPIED_ATTRIBUTES) unless const_defined?(:PREDECESSOR_COPIED_ATTRIBUTES, false)
  end

  def upgrade_with_predecessor!(to_model:, predecessor_name: nil)
    raise ArgumentError, "to_model is required" if to_model.blank?

    old_model_label = model_label

    self.class.transaction do
      predecessor = self.class.new(attributes.slice(*PREDECESSOR_COPIED_ATTRIBUTES))
      predecessor.name = predecessor_name.presence || "#{name} (#{old_model_label})"
      predecessor.save!

      memories.kept.find_each do |memory|
        predecessor.memories.create!(
          content: memory.content,
          memory_type: memory.memory_type,
          constitutional: memory.constitutional,
          created_at: memory.created_at
        )
      end

      update!(model_id: to_model)

      predecessor
    end
  end

end
