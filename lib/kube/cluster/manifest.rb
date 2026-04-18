# frozen_string_literal: true

require_relative "manifest/stack"
require_relative "manifest/middleware"
require_relative "manifest/middleware/namespace"
require_relative "manifest/middleware/labels"
require_relative "manifest/middleware/annotations"
require_relative "manifest/middleware/resource_preset"
require_relative "manifest/middleware/security_context"
require_relative "manifest/middleware/pod_anti_affinity"
require_relative "manifest/middleware/service_for_deployment"
require_relative "manifest/middleware/ingress_for_service"
require_relative "manifest/middleware/hpa_for_deployment"

module Kube
  module Cluster
    # A Manifest subclass that runs resources through a middleware stack
    # on enumeration. Manifests represent files — resources pass through
    # middleware before rendering or saving.
    #
    #   class MyApp < Kube::Cluster::Manifest
    #     stack do
    #       use Middleware::Namespace, "production"
    #       use Middleware::Labels, app: "web-app"
    #       use Middleware::ResourcePreset
    #     end
    #   end
    #
    #   app = MyApp.new
    #   app << Kube::Schema["Deployment"].new { ... }
    #   app.to_yaml  # resources have been transformed by the stack
    #
    class Manifest < Kube::Schema::Manifest
      # Declare a middleware stack at the class level.
      #
      #   stack do
      #     use Middleware::ResourcePreset
      #     use Middleware::SecurityContext
      #   end
      #
      def self.stack(&block)
        @stack = Stack.new(&block)
      end

      # Enumerate resources after passing them through the middleware
      # stack. The entire manifest is passed to the stack so that
      # generative middleware can introduce new resources that
      # subsequent stages will see and process.
      #
      # Every method that reads the manifest (to_yaml, to_a, map,
      # select, etc.) goes through here.
      def each(&block)
        return enum_for(:each) unless block

        stack = self.class.instance_variable_get(:@stack)
        if stack
          stack.call(@resources).each(&block)
        else
          @resources.each(&block)
        end
      end

      # Override to_yaml so it renders through the middleware stack.
      # The parent class accesses @resources directly, bypassing each.
      def to_yaml
        map { |r| r.to_yaml }.join("")
      end

      # Override to_a so it returns middleware-processed resources.
      # The parent class returns @resources.dup directly.
      def to_a
        map(&:itself)
      end
    end
  end
end
