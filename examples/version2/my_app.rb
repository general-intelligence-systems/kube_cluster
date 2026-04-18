# frozen_string_literal: true

require_relative "helpers"

module App
  class MyApp < Kube::Schema::Manifest
    include Helpers

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
    # Middleware reads these to apply sizing, affinity, etc.
    def app_labels
      {
        "app.kubernetes.io/domain":       @domain,
        "app.kubernetes.io/rails-domain": @rails_domain,
        "app.kubernetes.io/db-domain":    @db_domain,
        "app.kubernetes.io/size":         @size.to_s,
      }
    end
  end
end
