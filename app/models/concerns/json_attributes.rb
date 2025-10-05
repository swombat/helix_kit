# IMPORTANT: Why this concern exists despite appearing to violate Rails conventions
#
# This concern solves a critical Rails limitation: as_json does NOT recursively call
# as_json on associated objects. When you define as_json on a model and include
# associations, Rails will serialize those associations using their default
# serialization, ignoring any custom as_json methods defined on those models.
#
# This breaks encapsulation and forces parent models to know about the internal
# serialization details of their associations. The JsonAttributes concern fixes this
# by ensuring that when associations are included in JSON serialization, they use
# their own json_attributes configuration.
#
# Example of the Rails limitation this solves:
#   class User < ApplicationRecord
#     def as_json(options = {})
#       super(only: [:id, :name])
#     end
#   end
#
#   class Account < ApplicationRecord
#     has_many :users
#     def as_json(options = {})
#       super(include: :users)  # Users will NOT use their custom as_json!
#     end
#   end
#
# With JsonAttributes, each model defines its own serialization once, and it works
# correctly when included as an association. This maintains proper encapsulation
# and follows the DRY principle better than Rails' default behavior.
#
# Yes, this adds metaprogramming complexity, but it's a necessary workaround for
# a design limitation in Rails that would otherwise lead to duplicated and
# fragile serialization logic scattered throughout the codebase.

module JsonAttributes

  extend ActiveSupport::Concern

  class_methods do
    def json_attributes(*attrs, **options, &block)
      @json_attrs = attrs
      @json_includes = options.delete(:include) || {}
      @json_options = options
      @json_enhancer = block

      # Override serializable_hash to apply our configuration
      define_method :serializable_hash do |runtime_options = nil|
        runtime_options ||= {}

        # Build our configured options
        configured_options = {
          methods: self.class.json_attrs,
          include: self.class.json_includes
        }.merge(self.class.json_options)

        # Merge with runtime options
        merged_options = self.class.merge_json_options(configured_options, runtime_options)

        # Extract context options that should propagate to associations
        context = extract_context_options(merged_options)

        # Process includes to ensure nested models use their json_attributes
        if merged_options[:include]
          merged_options[:include] = process_includes_for_nesting(merged_options[:include], context)
        end

        # Get the base hash from Rails
        hash = super(merged_options)

        # Apply custom enhancements via the block
        if enhancer = self.class.json_enhancer
          instance_exec(hash, runtime_options, &enhancer)
        end

        hash["id"] = to_param

        # Clean up boolean keys
        self.class.clean_boolean_keys(hash)
      end

      # Also override as_json to ensure it works at the top level
      define_method :as_json do |options = nil|
        serializable_hash(options)
      end
    end

    attr_reader :json_attrs, :json_includes, :json_options, :json_enhancer

    def merge_json_options(base, overrides)
      return base if overrides.blank?

      result = base.dup

      # Merge arrays
      [ :methods, :only, :except ].each do |key|
        if base[key] || overrides[key]
          result[key] = Array(base[key]) | Array(overrides[key])
        end
      end

      # Deep merge includes
      if base[:include] || overrides[:include]
        result[:include] = deep_merge_includes(base[:include], overrides[:include])
      end

      # Pass through other options (like current_user)
      overrides.each do |key, value|
        next if [ :methods, :only, :except, :include ].include?(key)
        result[key] = value
      end

      result
    end

    def clean_boolean_keys(hash)
      hash.transform_keys do |key|
        key.to_s.end_with?("?") ? key.to_s[0..-2] : key
      end
    end

    private

    def deep_merge_includes(base, override)
      return override if base.nil?
      return base if override.nil?

      base_hash = normalize_include(base)
      override_hash = normalize_include(override)

      base_hash.deep_merge(override_hash) do |key, old_val, new_val|
        merge_json_options(old_val || {}, new_val || {})
      end
    end

    def normalize_include(include_value)
      case include_value
      when Symbol
        { include_value => {} }
      when Array
        include_value.each_with_object({}) do |item, hash|
          if item.is_a?(Hash)
            hash.merge!(item)
          else
            hash[item] = {}
          end
        end
      when Hash
        include_value
      else
        {}
      end
    end
  end

  private

  # Extract options that should propagate to nested associations
  def extract_context_options(options)
    options.slice(:current_user, :scope, :context).compact
  end

  # Process includes to ensure nested models use their json_attributes
  def process_includes_for_nesting(includes, context)
    return includes if context.empty?

    case includes
    when Symbol, String
      # Simple include - add context
      { includes => context }
    when Array
      # Array of includes - process each
      includes.map { |inc| process_single_include(inc, context) }
    when Hash
      # Hash of includes with options - merge context into each
      includes.transform_values do |opts|
        if opts.is_a?(Hash)
          opts.merge(context)
        else
          context
        end
      end
    else
      includes
    end
  end

  def process_single_include(include_item, context)
    case include_item
    when Symbol, String
      { include_item => context }
    when Hash
      include_item.transform_values do |opts|
        if opts.is_a?(Hash)
          opts.merge(context)
        else
          context
        end
      end
    else
      include_item
    end
  end

end
