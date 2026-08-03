# frozen_string_literal: true
#
# juicefs.io/v1 Sync — a one-shot `juicefs sync` job run by the juicefs-operator
# (https://juicefs.com/docs/csi/guide/juicefs-operator/).
#
# The operator builds a manager pod (plus `replicas - 1` worker pods) from
# `image`, parses each sink into a URI, and runs
# `juicefs sync [--<options>] <from> <to>`.
#
# `from`/`to` are the CRD's sink hashes and are passed through as-is — they are
# the meaningful configuration, so wrapping them in a mini-DSL would only hide
# the CRD. Exactly one of these keys per sink:
#
#   external:  { uri:, accessKey:, secretKey:, extraVolumes: }  any object store,
#              a `file://` path, or a mounted PVC/hostPath
#   juicefs:   { volumeName:, token:, ... }                     enterprise edition
#   juicefsCE: { metaURL:, metaPassWord:, path: }               community edition
#
# NOTE ON juicefsCE: the operator emits its metadata-URL export UNQUOTED
# (pkg/utils/sync.go, `export %s=%s`). A metaurl containing a literal `&` (e.g.
# `?sslmode=require&search_path=juicefs`) is split by the pod's `sh -c`
# entrypoint — the export runs in a background subshell and the variable is
# empty in the shell that runs the sync. Use an `external` sink with a `pvc`
# extraVolume instead, and let the CSI mount pod do the JuiceFS work.
#
# NOTE ON ttlSecondsAfterFinished: DO NOT SET IT when the Sync is managed by a
# reconciler such as Flux or Argo CD. The controller DELETES the Sync object
# when the TTL expires (internal/controller/sync_controller.go); the reconciler
# then sees drift, recreates it, and the sync runs again — forever. Without a
# TTL the object simply stays `Completed`. To re-run, delete the object by hand
# or switch to a CronSync.

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module JuiceFS
        class Sync < Kube::Cluster["juicefs.io/v1/Sync"]
          def initialize(name:, image:, from:, to:, replicas: 1, options: [], &block)
            super() {
              metadata.name = name
              spec.image    = image
              spec.replicas = replicas
              spec.options  = options if options.any?
              spec.from     = from
              spec.to       = to

              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "JuiceFS::Sync" do
  sync = Kube::Cluster::Standard::JuiceFS::Sync

  it "emits the juicefs.io/v1 apiVersion" do
    sync
      .new(
        name:  "media-backup",
        image: "juicedata/mount:latest",
        from:  { external: { uri: "file:///mnt/media/" } },
        to:    { external: { uri: "s3://backup.example.com/media/" } },
      )
      .to_yaml
      .include?("apiVersion: juicefs.io/v1")
      .should == true
  end

  it "omits options when none are given" do
    sync
      .new(
        name:  "plain",
        image: "juicedata/mount:latest",
        from:  { external: { uri: "file:///a/" } },
        to:    { external: { uri: "file:///b/" } },
      )
      .to_yaml
      .include?("options:")
      .should == false
  end

  it "carries options and replicas through" do
    yaml = sync.new(
      name:     "parallel",
      image:    "juicedata/mount:latest",
      from:     { external: { uri: "file:///a/" } },
      to:       { external: { uri: "file:///b/" } },
      replicas: 3,
      options:  ["--update"],
    ).to_yaml

    yaml.include?("replicas: 3").should == true
    yaml.include?("--update").should  == true
  end
end
