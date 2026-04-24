# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    class Container < Kube::Schema::SubSpec["Container"]
    end
  end
end

test do
  it "creates a valid container" do
    c = Kube::Cluster::Container.new(name: "app", image: "nginx:1.27")
    c.valid?.should.be.true
    c.name.should == "app"
  end

  it "auto-coerces inside a Deployment" do
    c = Kube::Cluster::Container.new(name: "app", image: "nginx:1.27")

    deploy = Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.replicas = 1
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [c]
    }

    deploy.to_h[:spec][:template][:spec][:containers].first[:name].should == "app"
  end
end
