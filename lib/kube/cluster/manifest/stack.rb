# frozen_string_literal: true

module Kube
  module Cluster
    class Manifest < Kube::Schema::Manifest
      # An ordered pipeline of middleware that transforms resources
      # one at a time as they flow out of the manifest enumerator.
      #
      #   stack = Kube::Cluster::Manifest::Stack.new do
      #     use Middleware::Namespace, "production"
      #     use Middleware::Labels, app: "web"
      #     use Middleware::ResourcePreset
      #   end
      #
      #   transformed = stack.call(resource)
      #
      class Stack
        def initialize(&block)
          @middleware = []
          instance_eval(&block) if block
        end

        # Register a middleware class with optional positional and keyword arguments.
        #
        # @param klass [Class] a Middleware subclass
        # @param args  [Array] positional arguments forwarded to klass.new
        # @param kwargs [Hash] keyword arguments forwarded to klass.new
        def use(klass, *args, **kwargs)
          @middleware << [klass, args, kwargs]
        end

        # Run a single resource through every middleware in order.
        #
        # @param resource [Kube::Schema::Resource]
        # @return [Kube::Schema::Resource]
        def call(resource)
          @middleware.reduce(resource) do |res, (klass, args, kwargs)|
            klass.new(*args, **kwargs).call(res)
          end
        end

        # True when no middleware has been registered.
        def empty?
          @middleware.empty?
        end
      end
    end
  end
end
