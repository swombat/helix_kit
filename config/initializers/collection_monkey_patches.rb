unless Hash.new.respond_to?(:deep_compact!) && Array.new.respond_to?(:attributize!)
  class Hash

    # Remove nil values from nested hashes
    def deep_compact!
      each do |key, value|
        if value.is_a?(Hash)
          value.deep_compact!
        end
      end
      delete_if { |_, value| value.nil? }
      self
    end

    # Recursively convert keys to symbols if they are strings, and turn those keys into methods
    # Enables { "key" => "value" }.key == "value" and { "key" => "value" }.key? == true
    def attributize!
      @attributized = true
      keys.each do |key|
        self[key].attributize! if self[key].respond_to?(:attributize!)
      end
      self
    end

    def method_missing(method, *args, &block)
      if @attributized
        self[method] || self[method.to_s]
      else
        super
      end
    end

    # Remove a specific set of keys from a hash, insensitive to whether they are strings or symbols
    def remove_keys!(*remove_keys)
      remove_keys.each do |key|
        self.delete(key)
        self.delete(key.to_s)
      end
      each do |key, value|
        if value.is_a?(Hash)
          value.remove_keys!(*remove_keys)
        end
      end
      self
    end

  end

  class Array

    # Recursively convert keys to symbols if they are strings, and turn those keys into methods
    # Enables { "key" => "value" }.key == "value" and { "key" => "value" }.key? == true
    def attributize!
      self.each do |item|
        item.attributize! if item.respond_to?(:attributize!)
      end
    end

  end
end
