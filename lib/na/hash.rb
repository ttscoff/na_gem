# frozen_string_literal: true

class ::Hash
  # Convert all keys in the hash to symbols recursively
  #
  # @return [Hash] Hash with symbolized keys
  def symbolize_keys
    each_with_object({}) { |(k, v), hsh| hsh[k.to_sym] = v.is_a?(Hash) ? v.symbolize_keys : v }
  end

  #
  # Freeze all values in a hash
  #
  # @return     Hash with all values frozen
  def deep_freeze
    chilled = {}
    each do |k, v|
      chilled[k] = v.is_a?(Hash) ? v.deep_freeze : v.freeze
    end

    chilled.freeze
  end

  # Freeze all values in a hash in place
  #
  # @return [Hash] Hash with all values frozen
  def deep_freeze!
    replace deep_thaw.deep_freeze
  end

  # Recursively duplicate all values in a hash
  #
  # @return [Hash] Hash with all values duplicated
  def deep_thaw
    chilled = {}
    each do |k, v|
      chilled[k] = v.is_a?(Hash) ? v.deep_thaw : v.dup
    end

    chilled.dup
  end

  # Recursively duplicate all values in a hash in place
  #
  # @return [Hash] Hash with all values duplicated
  def deep_thaw!
    replace deep_thaw
  end

  # Recursively merge two hashes, combining arrays and preferring non-nil values
  #
  # @param second [Hash] The hash to merge with
  # @return [Hash] The merged hash
  # Recursively merge two hashes, combining arrays and preferring non-nil values
  #
  # @param second [Hash] The hash to merge with
  # @return [Hash] The merged hash
  def deep_merge(second)
    merger = proc { |_, v1, v2|
      if v1.is_a?(Hash) && v2.is_a?(Hash)
        v1.merge(v2, &merger)
      elsif v1.is_a?(Array) && v2.is_a?(Array)
        v1 | v2
      else
        [:undefined, nil, :nil].include?(v2) ? v1 : v2
      end
    }
    merge(second.to_h, &merger)
  end
end
