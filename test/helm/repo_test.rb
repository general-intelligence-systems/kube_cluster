# frozen_string_literal: true

require "test_helper"

class RepoTest < Minitest::Test
  # ── initialization ────────────────────────────────────────────────────

  def test_initializes_with_name_and_url
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    assert_equal "bitnami", repo.name
    assert_instance_of Kube::Helm::Endpoint, repo.endpoint
    assert_equal "https://charts.bitnami.com/bitnami", repo.endpoint.url
  end

  def test_raises_on_empty_name
    assert_raises(ArgumentError) do
      Kube::Helm::Repo.new("", url: "https://charts.example.com")
    end
  end

  def test_raises_on_nil_name
    assert_raises(ArgumentError) do
      Kube::Helm::Repo.new(nil, url: "https://charts.example.com")
    end
  end

  # ── oci? delegation ──────────────────────────────────────────────────

  def test_oci_returns_true_for_oci_url
    repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
    assert repo.oci?
  end

  def test_oci_returns_false_for_http_url
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    refute repo.oci?
  end

  # ── add / update / remove ────────────────────────────────────────────

  def test_add_returns_self_for_oci
    repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
    assert_equal repo, repo.add
  end

  def test_update_returns_self_for_oci
    repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
    assert_equal repo, repo.update
  end

  def test_remove_returns_self_for_oci
    repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
    assert_equal repo, repo.remove
  end

  def test_add_runs_helm_repo_add
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

    captured_cmd = nil
    Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; "" }) do
      result = repo.add
      assert_equal repo, result
    end

    assert_includes captured_cmd, "repo"
    assert_includes captured_cmd, "add"
    assert_includes captured_cmd, "bitnami"
    assert_includes captured_cmd, "https://charts.bitnami.com/bitnami"
  end

  def test_update_runs_helm_repo_update
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

    captured_cmd = nil
    Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; "" }) do
      repo.update
    end

    assert_includes captured_cmd, "repo"
    assert_includes captured_cmd, "update"
    assert_includes captured_cmd, "bitnami"
  end

  def test_remove_runs_helm_repo_remove
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

    captured_cmd = nil
    Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; "" }) do
      repo.remove
    end

    assert_includes captured_cmd, "repo"
    assert_includes captured_cmd, "remove"
    assert_includes captured_cmd, "bitnami"
  end

  # ── fetch ────────────────────────────────────────────────────────────

  def test_fetch_returns_chart_with_metadata
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

    stub_chart_yaml = {
      "name" => "nginx",
      "version" => "18.1.0",
      "appVersion" => "1.25.0",
    }.to_yaml

    captured_cmds = []
    Kube::Helm.stub(:run, ->(cmd) {
      captured_cmds << cmd
      cmd.include?("show") ? stub_chart_yaml : ""
    }) do
      chart = repo.fetch("nginx", version: "18.1.0")

      assert_instance_of Kube::Helm::Chart, chart
      assert_equal "nginx", chart.name
      assert_equal "18.1.0", chart.version
      assert_equal "1.25.0", chart.app_version
      assert_equal "bitnami/nginx", chart.ref
      assert_nil chart.path
    end

    # Should have run: repo add, repo update, show chart
    show_cmd = captured_cmds.find { |c| c.include?("show") && c.include?("chart") }
    assert show_cmd, "Expected a show chart command"
    assert_includes show_cmd, "bitnami/nginx"
    assert_includes show_cmd, "--version=18.1.0"
  end

  def test_fetch_without_version
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

    stub_chart_yaml = { "name" => "nginx", "version" => "18.1.0" }.to_yaml

    captured_cmds = []
    Kube::Helm.stub(:run, ->(cmd) {
      captured_cmds << cmd
      cmd.include?("show") ? stub_chart_yaml : ""
    }) do
      chart = repo.fetch("nginx")
      assert_instance_of Kube::Helm::Chart, chart
      assert_nil chart.path
    end

    show_cmd = captured_cmds.find { |c| c.include?("show") && c.include?("chart") }
    refute_includes show_cmd, "--version"
  end

  def test_fetch_propagates_cluster
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami", cluster: cluster)

    stub_chart_yaml = { "name" => "nginx", "version" => "18.1.0" }.to_yaml

    cluster.connection.helm.stub(:run, ->(cmd) {
      cmd.include?("show") ? stub_chart_yaml : ""
    }) do
      chart = repo.fetch("nginx", version: "18.1.0")
      assert_equal cluster, chart.cluster
      assert_equal "bitnami/nginx", chart.ref
    end
  end

  # ── cluster scoping ──────────────────────────────────────────────────

  def test_initializes_without_cluster
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    assert_nil repo.cluster
  end

  def test_initializes_with_cluster
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami", cluster: cluster)
    assert_equal cluster, repo.cluster
  end

  def test_add_uses_cluster_helm_instance
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami", cluster: cluster)

    captured_cmd = nil
    cluster.connection.helm.stub(:run, ->(cmd) { captured_cmd = cmd; "" }) do
      repo.add
    end

    assert_includes captured_cmd, "repo"
    assert_includes captured_cmd, "add"
    assert_includes captured_cmd, "bitnami"
  end

  # ── to_s ──────────────────────────────────────────────────────────────

  def test_to_s
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    assert_equal "bitnami (https://charts.bitnami.com/bitnami)", repo.to_s
  end
end
