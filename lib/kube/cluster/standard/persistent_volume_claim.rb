# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      class PersistentVolumeClaim < Kube::Cluster["PersistentVolumeClaim"]
        def initialize(name:, storage:, access_modes: ["ReadWriteOnce"], storage_class: nil, &block)
          super() {
            metadata.name = name
            spec.accessModes = access_modes
            spec.storageClassName = storage_class if storage_class
            spec.resources = { requests: { storage: storage } }
            instance_exec(&block) if block_given?
          }
        end
      end
    end
  end
end

test do
  describe "PersistentVolumeClaim" do
    it "initializes without error" do
      Kube::Cluster::Standard::PersistentVolumeClaim
        .new(
          name: "my-volume",
          storage: "25Gi",
        )
        .to_yaml
        .is_a?(String)
        .should == true
    end
  end
end
