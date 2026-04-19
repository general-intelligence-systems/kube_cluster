# frozen_string_literal: true

module Kube
  module Cluster
    # A flat, ordered collection of Kubernetes resources.
    #
    # Manifest is a pure resource collection. Middleware is applied
    # separately via Kube::Cluster::Middleware::Stack.
    #
    #   manifest = Kube::Cluster::Manifest.new
    #   manifest << Kube::Cluster["Deployment"].new { ... }
    #
    #   stack = Kube::Cluster::Middleware::Stack.new do
    #     use Middleware::Namespace, "production"
    #     use Middleware::Labels, app: "web-app"
    #   end
    #
    #   stack.call(manifest)
    #   manifest.to_yaml
    #
    class Manifest < Kube::Schema::Manifest
      attr_reader :resources
    end
  end
end
