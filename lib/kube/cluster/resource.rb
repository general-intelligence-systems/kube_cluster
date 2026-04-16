# frozen_string_literal: true

require "json"
require "open3"

module Kube
  module Cluster
    class Resource < Kube::Schema::Resource
      class CommandError < StandardError; end

      def initialize(hash = {}, &block)
        super
        snapshot!
      end

      # ── Identity ──────────────────────────────────────────────

      def kind       = @data.kind.to_s
      def api_version = @data.apiVersion.to_s
      def name       = @data.metadata.name.to_s
      def namespace  = @data.metadata.namespace.to_s

      def persisted?
        !name.empty?
      end

      # ── Dirty tracking ────────────────────────────────────────

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

      # ── Persistence ───────────────────────────────────────────

      def save
        if persisted? && changed?
          patch
        else
          apply
        end
      end

      def apply
        json = JSON.generate(deep_stringify_keys(to_h))
        kubectl("apply", "-f", "-", stdin: json)
        reload
        true
      end

      def patch(type: "strategic")
        raise CommandError, "cannot patch a resource without a name" unless persisted?

        diff = patch_data
        return false if diff.empty?

        json = JSON.generate(deep_stringify_keys(diff))
        kubectl(
          "patch", resource_type, name,
          *ns_flags,
          "--type", type,
          "-p", json
        )
        reload
        true
      end

      def delete
        raise CommandError, "cannot delete a resource without a name" unless persisted?

        kubectl("delete", resource_type, name, *ns_flags)
        true
      end

      def reload
        raise CommandError, "cannot reload a resource without a name" unless persisted?

        json = kubectl("get", resource_type, name, *ns_flags, "-o", "json")
        hash = JSON.parse(json)
        @data = BlackHoleStruct.new(hash)
        snapshot!
        self
      end

      # ── Diffing ───────────────────────────────────────────────

      def patch_data
        deep_diff(to_h, @clean)
      end

      private

        def snapshot!
          @clean = deep_dup(to_h)
        end

        # Returns a hash containing only the keys/sub-trees that differ from
        # the clean snapshot. This is suitable for a strategic-merge patch.
        def deep_diff(current, original)
          result = {}

          current.each do |key, cur_val|
            orig_val = original[key]

            if cur_val.is_a?(Hash) && orig_val.is_a?(Hash)
              nested = deep_diff(cur_val, orig_val)
              result[key] = nested unless nested.empty?
            elsif cur_val != orig_val
              result[key] = cur_val
            end
          end

          result
        end

        # Returns top-level keys that have changed.
        def diff_keys(current, original)
          keys = Set.new
          (current.keys | original.keys).each do |key|
            keys << key if current[key] != original[key]
          end
          keys.to_a
        end

        # Returns { key => [old_value, new_value] } for every changed top-level key.
        def build_changes(current, original)
          result = {}
          (current.keys | original.keys).each do |key|
            next if current[key] == original[key]
            result[key] = [original[key], current[key]]
          end
          result
        end

        def deep_dup(obj)
          case obj
          when Hash  then obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
          when Array then obj.map { |v| deep_dup(v) }
          else obj
          end
        end

        # ── kubectl helpers ───────────────────────────────────

        def resource_type
          kind.downcase
        end

        def ns_flags
          ns = namespace
          ns.empty? ? [] : ["-n", ns]
        end

        def kubectl(*args, stdin: nil)
          cmd = ["kubectl", *args]
          stdout, stderr, status = Open3.capture3(*cmd, stdin_data: stdin)
          raise CommandError, "kubectl #{args.first} failed: #{stderr.strip}" unless status.success?
          stdout
        end
    end
  end
end
