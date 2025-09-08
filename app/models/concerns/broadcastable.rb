# IMPORTANT: Why this custom broadcasting abstraction exists
#
# This is NOT unnecessary complexity - it's the core of our Svelte real-time
# synchronization system. While Rails' built-in broadcasting (Turbo Streams)
# works great for Hotwire/Turbo applications, it doesn't integrate elegantly
# with Svelte's reactive state management.
#
# This concern enables automatic, fine-grained synchronization between Rails
# models and Svelte components without requiring boilerplate code on either side:
#
# 1. **Svelte-Specific Protocol**: Broadcasts structured markers that Svelte
#    components can interpret to update specific reactive state properties,
#    not HTML fragments like Turbo Streams.
#
# 2. **Automatic Prop Mapping**: Maps Rails model changes to Svelte component
#    props automatically, keeping frontend state in sync without manual wiring.
#
# 3. **Collection Management**: Handles both single record and collection updates
#    with appropriate granularity (refresh single items vs entire collections).
#
# 4. **Clean Svelte Code**: Without this, every Svelte component would need
#    complex ActionCable subscription logic. With it, components just declare
#    which data they care about and updates happen automatically.
#
# Example of what Svelte code would look like WITHOUT this abstraction:
#   - Manual ActionCable subscription setup in every component
#   - Complex message parsing and state update logic
#   - Duplicate subscription management code across components
#   - Risk of memory leaks from unmanaged subscriptions
#
# With this abstraction, Svelte components simply work with reactive state
# and updates flow automatically when Rails models change. This is a worthwhile
# tradeoff that keeps our frontend code clean and maintainable.
#
# See /docs/synchronization-usage.md for how this enables elegant Svelte code.

module Broadcastable

  extend ActiveSupport::Concern

  included do
    after_commit :broadcast_refresh, on: [ :create, :update ]
    after_commit :broadcast_removal, on: :destroy

    class_attribute :broadcast_targets, default: []
    class_attribute :refresh_props, default: {}

    # Flag to skip broadcasting when being destroyed as part of parent destruction
    attr_accessor :skip_broadcast
  end

  private

  def broadcast_refresh
    return if skip_broadcast

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
    return if skip_broadcast

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

    # Helper to skip broadcasts when destroying dependent associations
    def skip_broadcasts_on_destroy(*associations)
      before_destroy do
        associations.each do |association|
          Array(send(association)).each { |record| record.skip_broadcast = true if record.respond_to?(:skip_broadcast=) }
        end
      end
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
