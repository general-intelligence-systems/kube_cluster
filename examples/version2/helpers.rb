# frozen_string_literal: true

module App
  module Helpers
    def fullname(release, component)
      "#{release}-#{component}"[0, 63].chomp("-")
    end

    def standard_labels(name:, instance:, version: nil, component: nil)
      labels = {
        "app.kubernetes.io/name":       name,
        "app.kubernetes.io/instance":   instance,
        "app.kubernetes.io/managed-by": "kube_cluster",
      }
      labels[:"app.kubernetes.io/version"]   = version   if version
      labels[:"app.kubernetes.io/component"] = component if component
      labels
    end

    def match_labels(name:, instance:, component: nil)
      labels = {
        "app.kubernetes.io/name":     name,
        "app.kubernetes.io/instance": instance,
      }
      labels[:"app.kubernetes.io/component"] = component if component
      labels
    end

    def base64(str)
      [str].pack("m0")
    end
  end
end
