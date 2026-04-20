class Namespace < Kube::Cluster["Namespace"]
  def initialize(name:, **options, &block)
    super {
      metadata.name = name
    }
  end
end
