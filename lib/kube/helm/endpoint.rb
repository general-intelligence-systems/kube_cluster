# frozen_string_literal: true

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
