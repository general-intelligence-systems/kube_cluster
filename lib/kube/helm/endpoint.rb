# frozen_string_literal: true

if __FILE__ == $0
  require "bundler/setup"
  require "kube/cluster"
end

module Kube
  module Helm
    # Abstracts the differences between Helm chart sources.
    #
    # Traditional Helm repos require `helm repo add` before charts can be
    # referenced, and charts are addressed as "repo-name/chart-name".
    #
    # OCI registries need no `repo add` step, and charts are addressed as
    # the full OCI URI: "oci://host/path/chart-name".
    #
    #   endpoint = Kube::Helm::Endpoint.new("https://charts.bitnami.com/bitnami")
    #   endpoint.oci?           #=> false
    #   endpoint.requires_add?  #=> true
    #   endpoint.chart_ref("nginx", repo_name: "bitnami")
    #   #=> "bitnami/nginx"
    #
    #   endpoint = Kube::Helm::Endpoint.new("oci://ghcr.io/my-org/charts")
    #   endpoint.oci?           #=> true
    #   endpoint.requires_add?  #=> false
    #   endpoint.chart_ref("nginx")
    #   #=> "oci://ghcr.io/my-org/charts/nginx"
    #
    class Endpoint
      attr_reader :url

      def initialize(url)
        raise ArgumentError, "url must be a String" unless url.is_a?(String)
        raise ArgumentError, "url must not be empty" if url.strip.empty?

        @url = url.chomp("/")
      end

      # Is this an OCI registry endpoint?
      def oci?
        @url.start_with?("oci://")
      end

      # Traditional Helm repos require `helm repo add`; OCI registries do not.
      def requires_add?
        !oci?
      end

      # Build the chart reference string Helm expects.
      #
      # For OCI:         "oci://host/path/chart-name"
      # For traditional: "repo-name/chart-name"
      #
      # @param chart_name [String] the chart name (e.g. "nginx")
      # @param repo_name [String, nil] the local repo alias (required for non-OCI)
      # @return [String]
      def chart_ref(chart_name, repo_name: nil)
        if oci?
          "#{@url}/#{chart_name}"
        else
          if repo_name.nil?
            raise ArgumentError,
              "repo_name is required for non-OCI endpoints"
          end

          "#{repo_name}/#{chart_name}"
        end
      end

      def to_s
        @url
      end

      def ==(other)
        other.is_a?(Endpoint) && other.url == @url
      end
    end
  end
end

if __FILE__ == $0
  require "minitest/autorun"

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
end
