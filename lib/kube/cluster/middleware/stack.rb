# frozen_string_literal: true

module Kube
  module Cluster
    class Middleware
      # An ordered pipeline of middleware that processes a manifest.
      #
      # @example
      #   stack = Kube::Cluster::Middleware::Stack.new do
      #     use Middleware::ServiceForDeployment
      #     use Middleware::Labels, app: "web"
      #     use Middleware::SetNamespace, "production"
      #   end
      #
      #   stack.call(manifest)
      class Stack
        def initialize(&block)
          @middleware = []
          if block
            instance_eval(&block)
          end
        end

        # Register a middleware class to run in the stack.
        # @parameter klass [Class] a Middleware subclass.
        # @parameter args [Array] positional arguments for #new.
        # @parameter kwargs [Hash] keyword arguments for #new.
        def use(klass, *args, **kwargs)
          @middleware << [klass, args, kwargs]
        end

        # Runs the manifest through every middleware, in order.
        # @parameter manifest [Manifest] the manifest to mutate.
        def call(manifest)
          @middleware.each do |klass, args, kwargs|
            klass.new(*args, **kwargs).call(manifest)
          end
        end

        # Runs the manifest through the stack, then emits YAML.
        # @parameter manifest [Manifest] the manifest to mutate and emit.
        #
        # @example Called inside the Stack block as the final step
        #   Middleware::Stack.new {
        #     use SetNamespace
        #     run manifest
        #   }
        def run(manifest)
          call(manifest)
          puts manifest.to_yaml
        end

        # @returns [Boolean] true when no middleware has been registered.
        def empty?
          @middleware.empty?
        end
      end
    end
  end
end
