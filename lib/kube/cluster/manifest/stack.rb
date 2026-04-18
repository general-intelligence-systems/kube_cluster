# frozen_string_literal: true

module Kube
  module Cluster
    class Manifest < Kube::Schema::Manifest
      # An ordered pipeline of middleware that processes the full manifest
      # at each stage. Each stage flat_maps individual resources through
      # a single middleware — so generative middleware can introduce new
      # resources that subsequent stages will see and process.
      #
      #   stack = Kube::Cluster::Manifest::Stack.new do
      #     use Middleware::ServiceForDeployment   # generates Services
      #     use Middleware::Labels, app: "web"      # labels everything, including generated Services
      #     use Middleware::ResourcePreset          # sizes everything
      #   end
      #
      #   processed = stack.call(resources)
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

        # Run the full resource array through every middleware stage in order.
        # At each stage, every resource is passed individually through the
        # middleware. Middleware can return a single resource (transform) or
        # an array of resources (generative). The results are collected into
        # the array for the next stage.
        #
        # @param resources [Array<Kube::Schema::Resource>]
        # @return [Array<Kube::Schema::Resource>]
        def call(resources)
          @middleware.reduce(resources) do |current, (klass, args, kwargs)|
            middleware = klass.new(*args, **kwargs)
            current.flat_map { |r| Array(middleware.call(r)) }
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
