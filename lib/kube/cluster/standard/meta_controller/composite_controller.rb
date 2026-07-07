# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster   
    module Standard
      module MetaController
        class CompositeController < Kube::Cluster['CompositeController'] 
          def initialize(
            name:, webhook_url:,
            resync_period: 30, parent_resource:, child_resources: {}, &block
          )

            resolved_parent   = resolve_ref(parent_resource)
            resolved_children = resolve_hash(child_resources)
    
            super() {
              metadata.name = "#{name}-composite-controller"
              
              spec.generateSelector    = true
              spec.resyncPeriodSeconds = resync_period
              spec.hooks.sync.webhook  = { url: webhook_url }
              spec.parentResource      = resolved_parent
              spec.childResources      = resolved_children
              
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

__END__

describe "MetaController::CompositeController" do
  it "initializes without error" do
    Kube::Cluster::Standard::MetaController::CompositeController
      .new(
        name: "my-controller",
        webhook_url: "http://hook.default.svc/sync",
        parent_resource: { apiVersion: "apps/v1", resource: "deployments" },
      )
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
