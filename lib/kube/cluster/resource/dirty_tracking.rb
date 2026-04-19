# frozen_string_literal: true

module Kube
  module Cluster
    class Resource < Kube::Schema::Resource
      module DirtyTracking
        def changed?
          to_h != @clean
        end

        def changed
          diff_keys(to_h, @clean)
        end

        def changes
          build_changes(to_h, @clean)
        end

        def changes_applied
          snapshot!
        end

        # Data suitable for a strategic-merge patch: only the
        # keys/sub-trees that differ from the clean snapshot.
        def patch_data
          deep_diff(to_h, @clean)
        end

        def respond_to_missing?(name, include_private = false)
          if name.end_with?("_changed?")
            true
          else
            super
          end
        end

        def method_missing(name, *args, &block)
          if name.end_with?("_changed?")
            attr = name.to_s.delete_suffix("_changed?").to_sym
            old_val = @clean[attr]
            new_val = to_h[attr]
            old_val != new_val
          else
            super
          end
        end

        private

          def snapshot!
            @clean = deep_dup(to_h)
          end

          def deep_diff(current, original)
            Hash.new.tap do |result|
              merged_keys = current.keys | original.keys
            
              merged_keys.each do |key|
                cur_val  = current[key]
                orig_val = original[key]
            
                if cur_val.is_a?(Hash) && orig_val.is_a?(Hash)
                  nested = deep_diff(cur_val, orig_val)

                  if nested.empty?
                    next
                  else
                    result[key] = nested 
                  end
                elsif cur_val != orig_val
                  result[key] = [orig_val, cur_val]
                end
              end
            end
          end

          def diff_keys(current, original)
            Set.new.tap do |keys|
              merged_keys = (current.keys | original.keys)

              merged_keys.each do |key|
                if current[key] != original[key]
                  keys << key 
                end
              end
            end.to_a
          end

          def build_changes(current, original)
            Hash.new.tap do |hash|
              merged_keys = current.keys | original.keys

              merged_keys.each do |key|
                if current[key] == original[key]
                  next
                else
                  hash[key] = [deep_dup(original[key]), deep_dup(current[key])]
                end
              end
            end
          end

          def deep_dup(obj)
            case obj
            when Hash  then obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
            when Array then obj.map { |v| deep_dup(v) }
            else obj
            end
          end
      end
    end
  end
end
