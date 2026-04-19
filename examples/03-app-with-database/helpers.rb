# frozen_string_literal: true

module App
  module Helpers
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
