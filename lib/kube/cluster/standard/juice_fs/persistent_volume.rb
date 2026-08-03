# frozen_string_literal: true
#
# A statically-provisioned JuiceFS PersistentVolume.
#
# Dynamic provisioning (a `juicefs-sc` StorageClass) names each volume's
# directory `pvc-<uuid>` at the root of the filesystem. Static provisioning lets
# the directory be named explicitly via the `subPath` volume attribute — the
# only way to get an exact, readable folder name.
#
# `secret`/`secret_namespace` point at the JuiceFS "volume credentials" Secret
# (name / metaurl / storage / bucket / keys / encrypt_rsa_key). PersistentVolume
# is cluster-scoped and nodePublishSecretRef carries its own namespace, so the
# PV, its PVC, and that Secret may all live in different namespaces. The mount
# pod always runs in the CSI driver's namespace regardless.
#
# `storage` is a label only — JuiceFS enforces no quota through this field.

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module JuiceFS
        class PersistentVolume < Kube::Cluster["PersistentVolume"]
          def initialize(name:, storage:, sub_path:, secret:, secret_namespace:,
                         access_modes: ["ReadWriteMany"], reclaim_policy: "Retain", &block)
            super() {
              metadata.name = name

              spec.capacity                      = { storage: storage }
              spec.accessModes                   = access_modes
              spec.persistentVolumeReclaimPolicy = reclaim_policy
              # Empty (not absent) so no StorageClass can claim this PV and the
              # matching PVC binds by volumeName alone.
              spec.storageClassName              = ""
              spec.csi = {
                driver:               "csi.juicefs.com",
                volumeHandle:         name,
                fsType:               "juicefs",
                nodePublishSecretRef: { name: secret, namespace: secret_namespace },
                volumeAttributes:     { subPath: sub_path },
              }

              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "JuiceFS::PersistentVolume" do
  pv = Kube::Cluster::Standard::JuiceFS::PersistentVolume

  volume = pv.new(
    name:             "media",
    storage:          "1Ti",
    sub_path:         "media",
    secret:           "juicefs-secret",
    secret_namespace: "kube-system",
  )

  it "mounts the named subPath through the JuiceFS CSI driver" do
    yaml = volume.to_yaml

    yaml.include?("driver: csi.juicefs.com").should == true
    yaml.include?("subPath: media").should       == true
  end

  it "defaults to a retained, ReadWriteMany volume with no StorageClass" do
    yaml = volume.to_yaml

    yaml.include?("persistentVolumeReclaimPolicy: Retain").should == true
    yaml.include?("ReadWriteMany").should                        == true
    yaml.include?("storageClassName: ''").should                 == true
  end
end
