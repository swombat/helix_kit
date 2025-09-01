module Broadcastable

  extend ActiveSupport::Concern

  included do
    after_commit :broadcast_refresh, on: [ :create, :update ]
    after_commit :broadcast_removal, on: :destroy

    class_attribute :broadcast_targets, default: []
    class_attribute :refresh_props, default: {}
  end

  private

  def broadcast_refresh
    # Broadcast to self
    broadcast_marker("#{self.class.name}:#{obfuscated_id}",
                    action: "refresh",
                    prop: self.class.refresh_props[:single] || model_prop_name)

    # Broadcast to configured targets
    self.class.broadcast_targets.each do |target|
      case target
      when :all
        # Admin collection broadcast
        broadcast_marker("#{self.class.name}:all",
                        action: "refresh",
                        prop: self.class.refresh_props[:collection] || model_prop_name.pluralize)
      when Symbol
        # Smart detection of association type
        if (association = self.class.reflect_on_association(target))
          if association.collection?
            # It's a has_many/has_and_belongs_to_many - broadcast to each
            send(target).each do |record|
              broadcast_marker("#{record.class.name}:#{record.obfuscated_id}",
                              action: "refresh")
            end
          else
            # It's a belongs_to/has_one - broadcast to single record
            if (record = send(target))
              broadcast_marker("#{record.class.name}:#{record.obfuscated_id}",
                              action: "refresh")
            end
          end
        else
          Rails.logger.warn "Broadcastable: Unknown target '#{target}' for #{self.class.name}"
        end
      end
    end
  end

  def broadcast_removal
    broadcast_marker("#{self.class.name}:#{obfuscated_id}",
                    action: "remove",
                    prop: self.class.refresh_props[:single] || model_prop_name)

    # Also broadcast removal to collections
    self.class.broadcast_targets.each do |target|
      case target
      when :all
        broadcast_marker("#{self.class.name}:all",
                        action: "remove",
                        prop: self.class.refresh_props[:collection] || model_prop_name.pluralize)
      when Symbol
        # Smart detection of association type
        if (association = self.class.reflect_on_association(target))
          if association.collection?
            # For removals, still notify all associated records
            send(target).each do |record|
              broadcast_marker("#{record.class.name}:#{record.obfuscated_id}",
                              action: "refresh")
            end
          else
            # It's a belongs_to/has_one
            if (record = send(target))
              broadcast_marker("#{record.class.name}:#{record.obfuscated_id}",
                              action: "refresh")
            end
          end
        else
          Rails.logger.warn "Broadcastable: Unknown target '#{target}' for #{self.class.name}"
        end
      end
    end
  end

  def broadcast_marker(channel, data)
    ActionCable.server.broadcast(channel, data)
  end

  def model_prop_name
    self.class.name.underscore
  end

  module ClassMethods

    def broadcasts_to(*targets)
      self.broadcast_targets = targets
    end

    def broadcasts_refresh_prop(name, collection: false, parent: false)
      if collection
        self.refresh_props = refresh_props.merge(collection: name.to_s)
      elsif parent
        self.refresh_props = refresh_props.merge(parent: name.to_s)
      else
        self.refresh_props = refresh_props.merge(single: name.to_s)
      end
    end

  end

end
