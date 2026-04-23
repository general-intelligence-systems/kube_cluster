# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

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

test do
  # ── OCI detection ──────────────────────────────────────────────────────

  it "oci_endpoint_detected" do
    endpoint = Kube::Helm::Endpoint.new("oci://ghcr.io/my-org/charts")
    endpoint.oci?.should.be.true
  end

  it "http_endpoint_not_oci" do
    endpoint = Kube::Helm::Endpoint.new("https://charts.bitnami.com/bitnami")
    endpoint.oci?.should.be.false
  end

  # ── requires_add? ─────────────────────────────────────────────────────

  it "oci_does_not_require_add" do
    endpoint = Kube::Helm::Endpoint.new("oci://ghcr.io/my-org/charts")
    endpoint.requires_add?.should.be.false
  end

  it "http_requires_add" do
    endpoint = Kube::Helm::Endpoint.new("https://charts.bitnami.com/bitnami")
    endpoint.requires_add?.should.be.true
  end

  # ── chart_ref ──────────────────────────────────────────────────────────

  it "oci_chart_ref" do
    endpoint = Kube::Helm::Endpoint.new("oci://ghcr.io/my-org/charts")
    endpoint.chart_ref("nginx").should == "oci://ghcr.io/my-org/charts/nginx"
  end

  it "oci_chart_ref_strips_trailing_slash" do
    endpoint = Kube::Helm::Endpoint.new("oci://ghcr.io/my-org/charts/")
    endpoint.chart_ref("nginx").should == "oci://ghcr.io/my-org/charts/nginx"
  end

  it "http_chart_ref_with_repo_name" do
    endpoint = Kube::Helm::Endpoint.new("https://charts.bitnami.com/bitnami")
    endpoint.chart_ref("nginx", repo_name: "bitnami").should == "bitnami/nginx"
  end

  it "http_chart_ref_raises_without_repo_name" do
    endpoint = Kube::Helm::Endpoint.new("https://charts.bitnami.com/bitnami")
    lambda { endpoint.chart_ref("nginx") }.should.raise ArgumentError
  end

  # ── validation ─────────────────────────────────────────────────────────

  it "raises_on_empty_url" do
    lambda { Kube::Helm::Endpoint.new("") }.should.raise ArgumentError
  end

  it "raises_on_non_string_url" do
    lambda { Kube::Helm::Endpoint.new(nil) }.should.raise ArgumentError
  end

  # ── to_s / equality ───────────────────────────────────────────────────

  it "to_s_returns_url" do
    endpoint = Kube::Helm::Endpoint.new("https://charts.example.com")
    endpoint.to_s.should == "https://charts.example.com"
  end

  it "equality" do
    a = Kube::Helm::Endpoint.new("https://charts.example.com")
    b = Kube::Helm::Endpoint.new("https://charts.example.com")
    a.should == b
  end

  it "inequality" do
    a = Kube::Helm::Endpoint.new("https://charts.example.com")
    b = Kube::Helm::Endpoint.new("oci://ghcr.io/my-org/charts")
    a.should.not == b
  end
end
