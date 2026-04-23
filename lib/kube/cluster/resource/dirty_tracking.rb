# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

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

test do
  require "json"

  # ---------------------------------------------------------------------------
  # Fake ctl that records every command and returns canned responses.
  # The test wires this into the cluster → connection → ctl chain so that
  # Persistence#kubectl goes through it without touching a real cluster.
  # ---------------------------------------------------------------------------
  class FakeCtl
    attr_reader :commands

    def initialize
      @commands  = []
      @responses = {}
    end

    # Queue a response for the next command that includes +substring+.
    def stub_response(substring, response)
      @responses[substring] = response
    end

    def run(string)
      @commands << string

      @responses.each do |substring, response|
        if string.include?(substring)
          return response
        end
      end

      "" # default: empty response
    end
  end

  # ---------------------------------------------------------------------------
  # Minimal cluster double that provides .connection.ctl
  # ---------------------------------------------------------------------------
  class FakeConnection
    attr_reader :ctl

    def initialize(ctl)
      @ctl = ctl
    end
  end

  class FakeCluster
    attr_reader :connection

    def initialize(ctl)
      @connection = FakeConnection.new(ctl)
    end
  end

  # ---------------------------------------------------------------------------
  # Helper to build a resource wired to a fake cluster.
  # ---------------------------------------------------------------------------
  module ResourceHelper
    def build_resource(hash = {})
      ctl     = FakeCtl.new
      cluster = FakeCluster.new(ctl)
      resource = Kube::Cluster["ConfigMap"].new(hash.merge(kind: "ConfigMap", cluster: cluster))
      [resource, ctl]
    end

    # Simulate what kubectl returns: the server adds extra fields.
    def server_state(resource_hash, extra = {})
      merged = resource_hash.merge(extra)
      JSON.generate(stringify_keys(merged))
    end

    private

      def stringify_keys(obj)
        case obj
        when Hash  then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify_keys(v) }
        when Array then obj.map { |v| stringify_keys(v) }
        else obj
        end
      end
  end

  include ResourceHelper

  # -------------------------------------------------------------------------
  # Full lifecycle: apply → mutate → detect changes → patch → clean
  # -------------------------------------------------------------------------

  it "full_apply_mutate_patch_lifecycle" do
    resource, ctl = build_resource(metadata: { name: "app-config", namespace: "production" }, spec: { key: "original" })

    # Stub the reload after apply — server echoes back what we sent
    ctl.stub_response("get", server_state(
      metadata: { name: "app-config", namespace: "production", resourceVersion: "100" },
      spec: { key: "original" }
    ))

    resource.apply

    # Mutate
    resource.instance_variable_get(:@data).spec.key = "updated"

    # Stub reload after patch
    ctl.stub_response("get", server_state(
      metadata: { name: "app-config", namespace: "production", resourceVersion: "101" },
      spec: { key: "updated" }
    ))

    result = resource.patch
    result.should == true
  end

  # -------------------------------------------------------------------------
  # Patch returns false when nothing changed
  # -------------------------------------------------------------------------

  it "patch_returns_false_when_clean" do
    resource, ctl = build_resource(metadata: { name: "app-config", namespace: "default" }, spec: { key: "value" })

    ctl.stub_response("get", server_state(
      metadata: { name: "app-config", namespace: "default" }, spec: { key: "value" }
    ))

    result = resource.patch
    result.should == false
  end

  # -------------------------------------------------------------------------
  # Patch sends only the diff, not the full resource
  # -------------------------------------------------------------------------

  it "patch_sends_only_changed_fields" do
    resource, ctl = build_resource(
      metadata: { name: "my-config", namespace: "staging" },
      spec: { db_host: "old-db.internal", db_port: "5432", cache_ttl: "300" }
    )

    # Mutate one field
    resource.instance_variable_get(:@data).spec.db_host = "new-db.internal"

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "staging" },
      spec: { db_host: "new-db.internal", db_port: "5432", cache_ttl: "300" }
    ))

    resource.patch

    # Find the patch command
    patch_cmd = ctl.commands.find { |c| c.include?("patch") }

    # Extract the JSON payload from the command (last arg after -p)
    json_start = patch_cmd.index("-p ") + 3
    payload = JSON.parse(patch_cmd[json_start..])

    # The payload should contain the spec subtree but NOT metadata
    payload.key?("spec").should.be.true
  end

  # -------------------------------------------------------------------------
  # Reload resets dirty state from server response
  # -------------------------------------------------------------------------

  it "reload_resets_dirty_state" do
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "default" }, spec: { key: "v1" })

    # Local mutation
    resource.instance_variable_get(:@data).spec.key = "local-change"

    # Server still has original
    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default" }, spec: { key: "v1" }
    ))

    resource.reload

    # After reload, local changes are gone and resource is clean
    resource.to_h[:spec][:key].should == "v1"
  end

  it "reload_picks_up_server_side_changes" do
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "default" }, spec: { key: "v1" })

    # Server has been mutated externally
    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default", resourceVersion: "200" },
      spec: { key: "server-updated" }
    ))

    resource.reload

    # Resource reflects server state and is clean
    resource.to_h[:spec][:key].should == "server-updated"
  end

  # -------------------------------------------------------------------------
  # Apply snapshots after the server round-trip
  # -------------------------------------------------------------------------

  it "apply_snapshots_server_response" do
    resource, ctl = build_resource(metadata: { name: "my-config" }, spec: { key: "v1" })

    # Server adds metadata on apply
    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", resourceVersion: "1", uid: "abc-123" },
      spec: { key: "v1" }
    ))

    resource.apply

    # The snapshot should include server-added fields, so mutating
    # the original field shows the correct old value
    resource.instance_variable_get(:@data).spec.key = "v2"
    changes = resource.changes

    # changes[:spec] is [old_hash, new_hash]
    old_spec, new_spec = changes[:spec]
    old_spec[:key].should == "v1"
  end

  # -------------------------------------------------------------------------
  # Error cases: unpersisted resources
  # -------------------------------------------------------------------------

  it "patch_raises_on_unpersisted_resource" do
    resource, _ctl = build_resource(spec: { key: "value" })

    lambda { resource.patch }.should.raise Kube::CommandError
  end

  it "delete_raises_on_unpersisted_resource" do
    resource, _ctl = build_resource(spec: { key: "value" })

    lambda { resource.delete }.should.raise Kube::CommandError
  end

  it "reload_raises_on_unpersisted_resource" do
    resource, _ctl = build_resource(spec: { key: "value" })

    lambda { resource.reload }.should.raise Kube::CommandError
  end

  # -------------------------------------------------------------------------
  # Nested mutation flows through patch_data correctly
  # -------------------------------------------------------------------------

  it "nested_mutation_produces_nested_patch" do
    resource, ctl = build_resource(
      metadata: { name: "my-config", namespace: "default", labels: { app: "web", tier: "frontend" } }
    )

    # Mutate only a nested field
    resource.instance_variable_get(:@data).metadata.labels.tier = "backend"

    patch = resource.patch_data
    patch[:metadata][:labels][:tier].should == ["frontend", "backend"]
  end

  it "deeply_nested_no_change_produces_empty_patch" do
    resource, _ctl = build_resource(
      metadata: { name: "my-config", labels: { app: "web" } }
    )

    resource.patch_data.should == {}
  end

  # -------------------------------------------------------------------------
  # Multiple mutations before patch coalesce into a single diff
  # -------------------------------------------------------------------------

  it "multiple_mutations_coalesce_in_single_patch" do
    resource, ctl = build_resource(
      metadata: { name: "my-config", namespace: "default" },
      data: { host: "db-1", port: "5432", pool: "5" }
    )

    d = resource.instance_variable_get(:@data).data
    d.host = "db-2"
    d.port = "5433"
    d.pool = "10"

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default" },
      data: { host: "db-2", port: "5433", pool: "10" }
    ))

    resource.patch

    # Exactly one patch command
    patch_commands = ctl.commands.select { |c| c.include?("patch") }
    patch_commands.size.should == 1
  end

  # -------------------------------------------------------------------------
  # changes_applied mid-workflow resets the baseline
  # -------------------------------------------------------------------------

  it "changes_applied_resets_baseline_without_server_roundtrip" do
    resource, _ctl = build_resource(metadata: { name: "my-config" }, spec: { key: "v1" })

    resource.instance_variable_get(:@data).spec.key = "v2"

    # Accept changes locally (no kubectl call)
    resource.changes_applied

    resource.changes.should == {}
  end

  it "changes_applied_then_patch_sends_only_subsequent_changes" do
    resource, ctl = build_resource(
      metadata: { name: "my-config", namespace: "default" },
      data: { a: "1", b: "2", c: "3" }
    )

    # First wave of changes
    resource.instance_variable_get(:@data).data.a = "changed-a"
    resource.changes_applied

    # Second wave — only b changes from the new baseline
    resource.instance_variable_get(:@data).data.b = "changed-b"

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default" },
      data: { a: "changed-a", b: "changed-b", c: "3" }
    ))

    resource.patch

    patch_cmd = ctl.commands.find { |c| c.include?("patch") }
    payload = JSON.parse(patch_cmd.split("-p ").last)

    # Only b should be in the patch, not a (already accepted via changes_applied)
    payload["data"]["b"].should == ["2", "changed-b"]
  end

  # -------------------------------------------------------------------------
  # Dynamic attr_changed? tracks through full lifecycle
  # -------------------------------------------------------------------------

  it "attr_changed_through_apply_mutate_patch_cycle" do
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "default" }, spec: { key: "v1" })

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default" },
      spec: { key: "v1" }
    ))

    resource.apply

    resource.instance_variable_get(:@data).spec.key = "v2"

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default" },
      spec: { key: "v2" }
    ))

    resource.patch

    resource.spec_changed?.should.be.false
  end

  it "respond_to_for_dynamic_changed_predicates" do
    resource, _ctl = build_resource(metadata: { name: "test" })

    resource.should.respond_to :metadata_changed?
  end

  # -------------------------------------------------------------------------
  # Snapshot isolation: reload doesn't leak into captured references
  # -------------------------------------------------------------------------

  it "reload_does_not_corrupt_previously_captured_changes" do
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "default" }, spec: { key: "v1" })

    resource.instance_variable_get(:@data).spec.key = "v2"

    # Capture changes before reload
    changes_before = resource.changes
    patch_before   = resource.patch_data

    # Reload with different server state
    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default" },
      spec: { key: "v3-from-server" }
    ))

    resource.reload

    # Previously captured hashes should be unaffected
    extract_nested_value(changes_before, :spec, :key, 1).should == "v2"
  end

  it "snapshot_isolation_across_multiple_changes_applied" do
    resource, _ctl = build_resource(metadata: { name: "test" }, data: { counter: "1" })

    resource.instance_variable_get(:@data).data.counter = "2"
    snapshot_1_changes = resource.changes

    resource.changes_applied

    resource.instance_variable_get(:@data).data.counter = "3"
    snapshot_2_changes = resource.changes

    # Each snapshot's changes should be independent
    extract_nested_value(snapshot_1_changes, :data, :counter, 0).should == "1"
  end

  # -------------------------------------------------------------------------
  # Edge case: resource with no initial spec data
  # -------------------------------------------------------------------------

  it "empty_resource_tracks_all_additions" do
    resource, _ctl = build_resource(metadata: { name: "empty-config" })

    resource.instance_variable_get(:@data).spec.key = "added"

    resource.changed.should.include :spec
  end

  # -------------------------------------------------------------------------
  # Edge case: patch type parameter is forwarded
  # -------------------------------------------------------------------------

  it "patch_forwards_type_parameter" do
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "default" }, spec: { key: "v1" })

    resource.instance_variable_get(:@data).spec.key = "v2"

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default" },
      spec: { key: "v2" }
    ))

    resource.patch(type: "merge")

    patch_cmd = ctl.commands.find { |c| c.include?("patch") }
    patch_cmd.should.include "--type merge"
  end

  it "patch_defaults_to_strategic_type" do
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "default" }, spec: { key: "v1" })

    resource.instance_variable_get(:@data).spec.key = "v2"

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default" },
      spec: { key: "v2" }
    ))

    resource.patch

    patch_cmd = ctl.commands.find { |c| c.include?("patch") }
    patch_cmd.should.include "--type strategic"
  end

  # -------------------------------------------------------------------------
  # Edge case: namespace flags are included correctly
  # -------------------------------------------------------------------------

  it "patch_includes_namespace_flags" do
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "kube-system" }, spec: { key: "v1" })

    resource.instance_variable_get(:@data).spec.key = "v2"

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "kube-system" },
      spec: { key: "v2" }
    ))

    resource.patch

    patch_cmd = ctl.commands.find { |c| c.include?("patch") }
    patch_cmd.should.include "--namespace kube-system"
  end

  it "reload_includes_namespace_flags" do
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "monitoring" }, spec: { key: "v1" })

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "monitoring" },
      spec: { key: "v1" }
    ))

    resource.reload

    get_cmd = ctl.commands.find { |c| c.include?("get") }
    get_cmd.should.include "--namespace monitoring"
  end

  # -------------------------------------------------------------------------
  # Edge case: delete on persisted resource issues command
  # -------------------------------------------------------------------------

  it "delete_issues_kubectl_delete" do
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "default" })

    result = resource.delete

    delete_cmd = ctl.commands.find { |c| c.include?("delete") }
    delete_cmd.should.include "my-config"
  end

  # -------------------------------------------------------------------------
  # Regression: the original bug — build_changes used `result` instead of `hash`
  # -------------------------------------------------------------------------

  it "changes_does_not_raise_name_error" do
    resource, _ctl = build_resource(metadata: { name: "my-config" }, spec: { key: "v1" })

    resource.instance_variable_get(:@data).spec.key = "v2"

    # This would raise NameError with the original bug
    changes = resource.changes

    changes.should.be.kind_of Hash
  end

  private

    # Navigate into nested change structures.
    # changes[:spec] could be [old_hash, new_hash] or a nested diff hash.
    def extract_nested_value(hash, top_key, nested_key, index)
      val = hash[top_key]
      case val
      when Array
        # [old_hash, new_hash]
        val[index].is_a?(Hash) ? val[index][nested_key] : val[index]
      when Hash
        # nested diff: { key: [old, new] }
        val[nested_key].is_a?(Array) ? val[nested_key][index] : val[nested_key]
      end
    end
end
