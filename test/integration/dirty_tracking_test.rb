# frozen_string_literal: true

require "test_helper"
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

# ===========================================================================
# Integration tests — exercises DirtyTracking through the Persistence layer,
# driving the full Resource → Persistence → kubectl → DirtyTracking cycle.
# ===========================================================================
class DirtyTrackingIntegrationTest < Minitest::Test
  include ResourceHelper

  # -------------------------------------------------------------------------
  # Full lifecycle: apply → mutate → detect changes → patch → clean
  # -------------------------------------------------------------------------

  def test_full_apply_mutate_patch_lifecycle
    resource, ctl = build_resource(metadata: { name: "app-config", namespace: "production" }, spec: { key: "original" })

    # Stub the reload after apply — server echoes back what we sent
    ctl.stub_response("get", server_state(
      metadata: { name: "app-config", namespace: "production", resourceVersion: "100" },
      spec: { key: "original" }
    ))

    resource.apply

    # Post-apply the resource should be clean (reload calls snapshot!)
    refute resource.changed?, "resource should be clean after apply + reload"
    assert_equal({}, resource.changes)
    assert_equal [], resource.changed

    # Mutate
    resource.instance_variable_get(:@data).spec.key = "updated"

    # Now dirty
    assert resource.changed?

    # Stub reload after patch
    ctl.stub_response("get", server_state(
      metadata: { name: "app-config", namespace: "production", resourceVersion: "101" },
      spec: { key: "updated" }
    ))

    result = resource.patch
    assert_equal true, result

    # Post-patch the resource should be clean again
    refute resource.changed?
    assert_equal({}, resource.changes)
  end

  # -------------------------------------------------------------------------
  # Patch returns false when nothing changed
  # -------------------------------------------------------------------------

  def test_patch_returns_false_when_clean
    resource, ctl = build_resource(metadata: { name: "app-config", namespace: "default" }, spec: { key: "value" })

    ctl.stub_response("get", server_state(
      metadata: { name: "app-config", namespace: "default" }, spec: { key: "value" }
    ))

    result = resource.patch
    assert_equal false, result, "patch should return false when nothing changed"

    # No patch command should have been issued
    patch_commands = ctl.commands.select { |c| c.include?("patch") }
    assert_empty patch_commands, "no kubectl patch should be issued when resource is clean"
  end

  # -------------------------------------------------------------------------
  # Patch sends only the diff, not the full resource
  # -------------------------------------------------------------------------

  def test_patch_sends_only_changed_fields
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
    refute_nil patch_cmd, "a kubectl patch command should have been issued"

    # Extract the JSON payload from the command (last arg after -p)
    json_start = patch_cmd.index("-p ") + 3
    payload = JSON.parse(patch_cmd[json_start..])

    # The payload should contain the spec subtree but NOT metadata
    assert payload.key?("spec"), "patch payload should include changed subtree"
    refute payload.key?("metadata"), "patch payload should not include unchanged top-level keys"
  end

  # -------------------------------------------------------------------------
  # Reload resets dirty state from server response
  # -------------------------------------------------------------------------

  def test_reload_resets_dirty_state
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "default" }, spec: { key: "v1" })

    # Local mutation
    resource.instance_variable_get(:@data).spec.key = "local-change"
    assert resource.changed?

    # Server still has original
    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default" }, spec: { key: "v1" }
    ))

    resource.reload

    # After reload, local changes are gone and resource is clean
    refute resource.changed?
    assert_equal "v1", resource.to_h[:spec][:key]
  end

  def test_reload_picks_up_server_side_changes
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "default" }, spec: { key: "v1" })

    # Server has been mutated externally
    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default", resourceVersion: "200" },
      spec: { key: "server-updated" }
    ))

    resource.reload

    # Resource reflects server state and is clean
    refute resource.changed?
    assert_equal "server-updated", resource.to_h[:spec][:key]
  end

  # -------------------------------------------------------------------------
  # Apply snapshots after the server round-trip
  # -------------------------------------------------------------------------

  def test_apply_snapshots_server_response
    resource, ctl = build_resource(metadata: { name: "my-config" }, spec: { key: "v1" })

    # Server adds metadata on apply
    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", resourceVersion: "1", uid: "abc-123" },
      spec: { key: "v1" }
    ))

    resource.apply

    refute resource.changed?

    # The snapshot should include server-added fields, so mutating
    # the original field shows the correct old value
    resource.instance_variable_get(:@data).spec.key = "v2"
    changes = resource.changes

    # changes[:spec] is [old_hash, new_hash]
    old_spec, new_spec = changes[:spec]
    assert_equal "v1", old_spec[:key]
    assert_equal "v2", new_spec[:key]

    # The resource should also have the server-added metadata
    assert resource.to_h.key?(:metadata)
  end

  # -------------------------------------------------------------------------
  # Error cases: unpersisted resources
  # -------------------------------------------------------------------------

  def test_patch_raises_on_unpersisted_resource
    resource, _ctl = build_resource(spec: { key: "value" })
    # No name → not persisted

    error = assert_raises(Kube::CommandError) { resource.patch }
    assert_match(/cannot patch/, error.message)
  end

  def test_delete_raises_on_unpersisted_resource
    resource, _ctl = build_resource(spec: { key: "value" })

    error = assert_raises(Kube::CommandError) { resource.delete }
    assert_match(/cannot delete/, error.message)
  end

  def test_reload_raises_on_unpersisted_resource
    resource, _ctl = build_resource(spec: { key: "value" })

    error = assert_raises(Kube::CommandError) { resource.reload }
    assert_match(/cannot reload/, error.message)
  end

  # -------------------------------------------------------------------------
  # Nested mutation flows through patch_data correctly
  # -------------------------------------------------------------------------

  def test_nested_mutation_produces_nested_patch
    resource, ctl = build_resource(
      metadata: { name: "my-config", namespace: "default", labels: { app: "web", tier: "frontend" } }
    )

    # Mutate only a nested field
    resource.instance_variable_get(:@data).metadata.labels.tier = "backend"

    patch = resource.patch_data
    assert_kind_of Hash, patch[:metadata], "patch_data should nest into metadata"
    assert_kind_of Hash, patch[:metadata][:labels], "patch_data should nest into labels"
    assert_equal ["frontend", "backend"], patch[:metadata][:labels][:tier]

    # Unchanged sibling should not appear
    refute patch[:metadata][:labels].key?(:app), "unchanged label should not appear in patch"
    refute patch.key?(:spec), "unchanged top-level key should not appear in patch"
  end

  def test_deeply_nested_no_change_produces_empty_patch
    resource, _ctl = build_resource(
      metadata: { name: "my-config", labels: { app: "web" } }
    )

    assert_equal({}, resource.patch_data)
  end

  # -------------------------------------------------------------------------
  # Multiple mutations before patch coalesce into a single diff
  # -------------------------------------------------------------------------

  def test_multiple_mutations_coalesce_in_single_patch
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
    assert_equal 1, patch_commands.size

    payload = JSON.parse(patch_commands.first.split("-p ").last)

    # deep_diff produces [old, new] tuples for each changed leaf
    assert_equal ["db-1", "db-2"], payload["data"]["host"]
    assert_equal ["5432", "5433"], payload["data"]["port"]
    assert_equal ["5", "10"], payload["data"]["pool"]
  end

  # -------------------------------------------------------------------------
  # changes_applied mid-workflow resets the baseline
  # -------------------------------------------------------------------------

  def test_changes_applied_resets_baseline_without_server_roundtrip
    resource, _ctl = build_resource(metadata: { name: "my-config" }, spec: { key: "v1" })

    resource.instance_variable_get(:@data).spec.key = "v2"
    assert resource.changed?
    assert_equal([:spec], resource.changed)

    # Accept changes locally (no kubectl call)
    resource.changes_applied

    refute resource.changed?
    assert_equal({}, resource.changes)

    # Further mutation is tracked from the new baseline
    resource.instance_variable_get(:@data).spec.key = "v3"
    assert resource.changed?

    changes = resource.changes
    # Old value should be v2 (the accepted baseline), not v1
    assert_equal "v2", changes[:spec].is_a?(Hash) ? changes[:spec][:key]&.first : nil,
      "baseline should be v2 after changes_applied" if changes[:spec].is_a?(Hash)
    assert_equal({ spec: [{ key: "v2" }, { key: "v3" }] }, changes) if changes[:spec].is_a?(Array)
  end

  def test_changes_applied_then_patch_sends_only_subsequent_changes
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
    # deep_diff produces [old, new] tuples
    assert_equal ["2", "changed-b"], payload["data"]["b"]
    refute payload["data"].key?("a"), "already-accepted change 'a' should not be in patch"
  end

  # -------------------------------------------------------------------------
  # Dynamic attr_changed? tracks through full lifecycle
  # -------------------------------------------------------------------------

  def test_attr_changed_through_apply_mutate_patch_cycle
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "default" }, spec: { key: "v1" })

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default" },
      spec: { key: "v1" }
    ))

    resource.apply

    refute resource.spec_changed?, "spec should not be changed after apply"
    refute resource.metadata_changed?, "metadata should not be changed after apply"

    resource.instance_variable_get(:@data).spec.key = "v2"

    assert resource.spec_changed?, "spec should be changed after mutation"
    refute resource.metadata_changed?, "metadata should still not be changed"

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default" },
      spec: { key: "v2" }
    ))

    resource.patch

    refute resource.spec_changed?, "spec should not be changed after patch"
  end

  def test_respond_to_for_dynamic_changed_predicates
    resource, _ctl = build_resource(metadata: { name: "test" })

    assert resource.respond_to?(:metadata_changed?)
    assert resource.respond_to?(:spec_changed?)
    assert resource.respond_to?(:anything_at_all_changed?)
    refute resource.respond_to?(:some_random_method)
  end

  # -------------------------------------------------------------------------
  # Snapshot isolation: reload doesn't leak into captured references
  # -------------------------------------------------------------------------

  def test_reload_does_not_corrupt_previously_captured_changes
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
    assert_equal "v2", extract_nested_value(changes_before, :spec, :key, 1),
      "previously captured changes should not be corrupted by reload"
    assert_equal "v2", extract_nested_value(patch_before, :spec, :key, 1),
      "previously captured patch_data should not be corrupted by reload"
  end

  def test_snapshot_isolation_across_multiple_changes_applied
    resource, _ctl = build_resource(metadata: { name: "test" }, data: { counter: "1" })

    resource.instance_variable_get(:@data).data.counter = "2"
    snapshot_1_changes = resource.changes

    resource.changes_applied

    resource.instance_variable_get(:@data).data.counter = "3"
    snapshot_2_changes = resource.changes

    # Each snapshot's changes should be independent
    assert_equal "1", extract_nested_value(snapshot_1_changes, :data, :counter, 0)
    assert_equal "2", extract_nested_value(snapshot_1_changes, :data, :counter, 1)

    assert_equal "2", extract_nested_value(snapshot_2_changes, :data, :counter, 0)
    assert_equal "3", extract_nested_value(snapshot_2_changes, :data, :counter, 1)
  end

  # -------------------------------------------------------------------------
  # Edge case: resource with no initial spec data
  # -------------------------------------------------------------------------

  def test_empty_resource_tracks_all_additions
    resource, _ctl = build_resource(metadata: { name: "empty-config" })

    resource.instance_variable_get(:@data).spec.key = "added"

    assert resource.changed?
    assert_includes resource.changed, :spec
  end

  # -------------------------------------------------------------------------
  # Edge case: patch type parameter is forwarded
  # -------------------------------------------------------------------------

  def test_patch_forwards_type_parameter
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "default" }, spec: { key: "v1" })

    resource.instance_variable_get(:@data).spec.key = "v2"

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default" },
      spec: { key: "v2" }
    ))

    resource.patch(type: "merge")

    patch_cmd = ctl.commands.find { |c| c.include?("patch") }
    assert_includes patch_cmd, "--type merge", "patch type should be forwarded to kubectl"
  end

  def test_patch_defaults_to_strategic_type
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "default" }, spec: { key: "v1" })

    resource.instance_variable_get(:@data).spec.key = "v2"

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "default" },
      spec: { key: "v2" }
    ))

    resource.patch

    patch_cmd = ctl.commands.find { |c| c.include?("patch") }
    assert_includes patch_cmd, "--type strategic"
  end

  # -------------------------------------------------------------------------
  # Edge case: namespace flags are included correctly
  # -------------------------------------------------------------------------

  def test_patch_includes_namespace_flags
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "kube-system" }, spec: { key: "v1" })

    resource.instance_variable_get(:@data).spec.key = "v2"

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "kube-system" },
      spec: { key: "v2" }
    ))

    resource.patch

    patch_cmd = ctl.commands.find { |c| c.include?("patch") }
    assert_includes patch_cmd, "--namespace kube-system"
  end

  def test_reload_includes_namespace_flags
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "monitoring" }, spec: { key: "v1" })

    ctl.stub_response("get", server_state(
      metadata: { name: "my-config", namespace: "monitoring" },
      spec: { key: "v1" }
    ))

    resource.reload

    get_cmd = ctl.commands.find { |c| c.include?("get") }
    assert_includes get_cmd, "--namespace monitoring"
  end

  # -------------------------------------------------------------------------
  # Edge case: delete on persisted resource issues command
  # -------------------------------------------------------------------------

  def test_delete_issues_kubectl_delete
    resource, ctl = build_resource(metadata: { name: "my-config", namespace: "default" })

    result = resource.delete
    assert_equal true, result

    delete_cmd = ctl.commands.find { |c| c.include?("delete") }
    refute_nil delete_cmd
    assert_includes delete_cmd, "configmap"
    assert_includes delete_cmd, "my-config"
    assert_includes delete_cmd, "--namespace default"
  end

  # -------------------------------------------------------------------------
  # Regression: the original bug — build_changes used `result` instead of `hash`
  # -------------------------------------------------------------------------

  def test_changes_does_not_raise_name_error
    resource, _ctl = build_resource(metadata: { name: "my-config" }, spec: { key: "v1" })

    resource.instance_variable_get(:@data).spec.key = "v2"

    # This would raise NameError with the original bug
    changes = resource.changes

    assert_kind_of Hash, changes
    refute changes.empty?
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
