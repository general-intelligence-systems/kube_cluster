# frozen_string_literal: true

class SelfSignedIssuer < Kube::Cluster["ClusterIssuer"]
  def initialize
    super {
      metadata.name = "selfsigned"

      spec.selfSigned = {}
    }
  end
end
