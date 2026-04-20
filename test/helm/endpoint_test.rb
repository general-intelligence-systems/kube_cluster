# frozen_string_literal: true

require "test_helper"

class EndpointTest < Minitest::Test
  # ── OCI detection ──────────────────────────────────────────────────────

  def test_oci_endpoint_detected
    endpoint = Kube::Helm::Endpoint.new("oci://ghcr.io/my-org/charts")
    assert endpoint.oci?
  end

  def test_http_endpoint_not_oci
    endpoint = Kube::Helm::Endpoint.new("https://charts.bitnami.com/bitnami")
    refute endpoint.oci?
  end

  # ── requires_add? ─────────────────────────────────────────────────────

  def test_oci_does_not_require_add
    endpoint = Kube::Helm::Endpoint.new("oci://ghcr.io/my-org/charts")
    refute endpoint.requires_add?
  end

  def test_http_requires_add
    endpoint = Kube::Helm::Endpoint.new("https://charts.bitnami.com/bitnami")
    assert endpoint.requires_add?
  end

  # ── chart_ref ──────────────────────────────────────────────────────────

  def test_oci_chart_ref
    endpoint = Kube::Helm::Endpoint.new("oci://ghcr.io/my-org/charts")
    assert_equal "oci://ghcr.io/my-org/charts/nginx", endpoint.chart_ref("nginx")
  end

  def test_oci_chart_ref_strips_trailing_slash
    endpoint = Kube::Helm::Endpoint.new("oci://ghcr.io/my-org/charts/")
    assert_equal "oci://ghcr.io/my-org/charts/nginx", endpoint.chart_ref("nginx")
  end

  def test_http_chart_ref_with_repo_name
    endpoint = Kube::Helm::Endpoint.new("https://charts.bitnami.com/bitnami")
    assert_equal "bitnami/nginx", endpoint.chart_ref("nginx", repo_name: "bitnami")
  end

  def test_http_chart_ref_raises_without_repo_name
    endpoint = Kube::Helm::Endpoint.new("https://charts.bitnami.com/bitnami")
    assert_raises(ArgumentError) { endpoint.chart_ref("nginx") }
  end

  # ── validation ─────────────────────────────────────────────────────────

  def test_raises_on_empty_url
    assert_raises(ArgumentError) { Kube::Helm::Endpoint.new("") }
  end

  def test_raises_on_non_string_url
    assert_raises(ArgumentError) { Kube::Helm::Endpoint.new(nil) }
  end

  # ── to_s / equality ───────────────────────────────────────────────────

  def test_to_s_returns_url
    endpoint = Kube::Helm::Endpoint.new("https://charts.example.com")
    assert_equal "https://charts.example.com", endpoint.to_s
  end

  def test_equality
    a = Kube::Helm::Endpoint.new("https://charts.example.com")
    b = Kube::Helm::Endpoint.new("https://charts.example.com")
    assert_equal a, b
  end

  def test_inequality
    a = Kube::Helm::Endpoint.new("https://charts.example.com")
    b = Kube::Helm::Endpoint.new("oci://ghcr.io/my-org/charts")
    refute_equal a, b
  end
end
