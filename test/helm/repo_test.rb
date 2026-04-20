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

  # ── add / update / remove skip OCI ────────────────────────────────────

  def test_add_returns_nil_for_oci
    repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
    assert_nil repo.add
  end

  def test_update_returns_nil_for_oci
    repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
    assert_nil repo.update
  end

  def test_remove_returns_nil_for_oci
    repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
    assert_nil repo.remove
  end

  # ── chart ──────────────────────────────────────────────────────────────

  def test_chart_returns_chart_for_http_repo
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    chart = repo.chart("nginx", version: "18.1.0")

    assert_instance_of Kube::Helm::Chart, chart
    assert_equal "bitnami/nginx", chart.ref
    assert_equal "18.1.0", chart.version
  end

  def test_chart_returns_chart_for_oci_repo
    repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
    chart = repo.chart("nginx", version: "1.0.0")

    assert_instance_of Kube::Helm::Chart, chart
    assert_equal "oci://ghcr.io/my-org/charts/nginx", chart.ref
    assert_equal "1.0.0", chart.version
  end

  def test_chart_without_version
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    chart = repo.chart("nginx")

    assert_nil chart.version
  end

  # ── cluster: param ──────────────────────────────────────────────────

  def test_initializes_without_cluster
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    assert_nil repo.cluster
  end

  def test_initializes_with_cluster
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami", cluster: cluster)
    assert_equal cluster, repo.cluster
  end

  def test_chart_propagates_cluster
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami", cluster: cluster)
    chart = repo.chart("nginx", version: "18.1.0")

    assert_equal cluster, chart.cluster
  end

  def test_chart_without_cluster_has_nil_cluster
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    chart = repo.chart("nginx")

    assert_nil chart.cluster
  end

  # ── to_s ──────────────────────────────────────────────────────────────

  def test_to_s
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    assert_equal "bitnami (https://charts.bitnami.com/bitnami)", repo.to_s
  end
end
