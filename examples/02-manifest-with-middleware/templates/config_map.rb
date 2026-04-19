class ConfigMap < Kube::Schema["ConfigMap"]
  def initialize(namespace:)
    build {
      metadata.name = "#{namespace}-config"
      spec.data = {
        RAILS_ENV:     "production",
        LOG_LEVEL:     "info",
        WORKERS:       "4",
        PORT:          "3000",
      }
    }
  end
end
