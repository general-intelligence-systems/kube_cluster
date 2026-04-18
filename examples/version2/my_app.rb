# frozen_string_literal: true

require_relative "helpers"

class MyApp < Kube::Cluster::Manifest
  include Helpers

  Middleware = Kube::Cluster::Manifest::Middleware

  stack do
    # Generative — produce new resources from existing ones
    use Middleware::ServiceForDeployment
    use Middleware::IngressForService
    use Middleware::HPAForDeployment

    # Transforms — apply to everything, including generated resources
    use Middleware::Labels, managed_by: "kube_cluster"
    use Middleware::ResourcePreset
    use Middleware::SecurityContext
    use Middleware::PodAntiAffinity
  end

  attr_reader :domain, :db_domain, :rails_domain, :size

  def initialize(domain, size: :small, &block)
    super()
    @domain       = domain
    @db_domain    = "db.#{domain}"
    @rails_domain = "app.#{domain}"
    @size         = size
    block.call(self) if block
  end

  # Labels that encode the manifest-level abstractions.
  # Middleware reads these to apply sizing, security, etc.
  def app_labels(name:, instance:, component: nil)
    labels = {
      "app.kubernetes.io/name":     name,
      "app.kubernetes.io/instance": instance,
      "app.kubernetes.io/size":     @size.to_s,
    }
    labels[:"app.kubernetes.io/component"] = component if component
    labels
  end
end
