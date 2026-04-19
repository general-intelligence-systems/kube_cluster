# frozen_string_literal: true

module Kube
  module Cluster
    class Middleware
      # An ordered pipeline of middleware that processes a manifest.
      # Each middleware receives the manifest and mutates it in place.
      #
      #   stack = Kube::Cluster::Middleware::Stack.new do
      #     use Middleware::ServiceForDeployment
      #     use Middleware::Labels, app: "web"
      #     use Middleware::Namespace, "production"
      #   end
      #
      #   stack.call(manifest)
      #
      class Stack
        def initialize(&block)
          @middleware = []
          instance_eval(&block) if block
        end

        # Register a middleware class with optional positional and keyword arguments.
        def use(klass, *args, **kwargs)
          @middleware << [klass, args, kwargs]
        end

        # Run the manifest through every middleware in order.
        # Each middleware mutates the manifest in place.
        def call(manifest)
          @middleware.each do |klass, args, kwargs|
            klass.new(*args, **kwargs).call(manifest)
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
