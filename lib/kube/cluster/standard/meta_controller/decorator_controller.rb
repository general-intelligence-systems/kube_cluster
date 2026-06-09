# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster   
    module Standard
      module MetaController
        class DecoratorController < Kube::Cluster['DecoratorController'] 
          def initialize(
            name:, webhook_url:,
            resync_period: 30, resources: {}, attachments: {}, &block
          )

            resolved_resources   = resolve_hash(resources)
            resolved_attachments = resolve_hash(attachments)

            super() {
              metadata.name = name

              spec.resources           = resolved_resources
              spec.attachments         = resolved_attachments
              spec.resyncPeriodSeconds = resync_period
              spec.hooks.sync.webhook  = { url: webhook_url }

              instance_exec(&block) if block
            }
          end

          private

            def resolve_ref(ref)
              if ref.is_a?(Hash)
                ref
              else
                if ref.is_a?(Class)
                  klass = ref
                else
                  klass = ref.class
                end

                {
                  apiVersion: klass.defaults['apiVersion'],
                  resource:   klass.defaults['kind'].downcase.pluralize
                }
              end 
            end

            def resolve_hash(hash)
              hash.map do |klass, options|
                resolve_ref(klass).merge(options || {})
              end
            end
        end
      end
    end
  end
end

test do
  describe "MetaController::DecoratorController" do
    it "initializes without error" do
      Kube::Cluster::Standard::MetaController::DecoratorController
        .new(
          name: "my-controller",
          webhook_url: "http://hook.default.svc/sync",
          resources: { { apiVersion: "v1", resource: "pods" } => {} },
        )
        .to_yaml
        .is_a?(String)
        .should == true
    end
  end
end
