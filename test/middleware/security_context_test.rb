# frozen_string_literal: true

require "test_helper"

class SecurityContextMiddlewareTest < Minitest::Test
  Middleware = Kube::Cluster::Manifest::Middleware

  def test_applies_restricted_profile_by_default
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    }

    result = Middleware::SecurityContext.new.call(resource)
    h = result.to_h
    pod_sc = h.dig(:spec, :template, :spec, :securityContext)
    container_sc = h.dig(:spec, :template, :spec, :containers, 0, :securityContext)

    assert_equal true, pod_sc[:runAsNonRoot]
    assert_equal 1000, pod_sc[:runAsUser]
    assert_equal 1000, pod_sc[:fsGroup]
    assert_equal({ type: "RuntimeDefault" }, pod_sc[:seccompProfile])

    assert_equal false, container_sc[:allowPrivilegeEscalation]
    assert_equal true, container_sc[:readOnlyRootFilesystem]
    assert_equal({ drop: ["ALL"] }, container_sc[:capabilities])
  end

  def test_applies_baseline_profile_via_label
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      metadata.labels = { "app.kubernetes.io/security": "baseline" }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    }

    result = Middleware::SecurityContext.new.call(resource)
    h = result.to_h
    pod_sc = h.dig(:spec, :template, :spec, :securityContext)
    container_sc = h.dig(:spec, :template, :spec, :containers, 0, :securityContext)

    assert_equal true, pod_sc[:runAsNonRoot]
    assert_nil pod_sc[:seccompProfile]

    assert_equal false, container_sc[:allowPrivilegeEscalation]
    assert_nil container_sc[:readOnlyRootFilesystem]
  end

  def test_applies_baseline_profile_via_constructor_default
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    }

    result = Middleware::SecurityContext.new(default: :baseline).call(resource)
    h = result.to_h
    pod_sc = h.dig(:spec, :template, :spec, :securityContext)

    assert_nil pod_sc[:seccompProfile]
  end

  def test_label_overrides_constructor_default
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      metadata.labels = { "app.kubernetes.io/security": "restricted" }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    }

    result = Middleware::SecurityContext.new(default: :baseline).call(resource)
    h = result.to_h
    pod_sc = h.dig(:spec, :template, :spec, :securityContext)

    assert_equal({ type: "RuntimeDefault" }, pod_sc[:seccompProfile])
  end

  def test_applies_to_all_containers
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "app", image: "app:latest" },
        { name: "sidecar", image: "sidecar:latest" },
      ]
    }

    result = Middleware::SecurityContext.new.call(resource)
    containers = result.to_h.dig(:spec, :template, :spec, :containers)

    containers.each do |c|
      assert_equal false, c.dig(:securityContext, :allowPrivilegeEscalation)
    end
  end

  def test_skips_non_pod_bearing_resources
    resource = Kube::Schema["ConfigMap"].new {
      metadata.name = "config"
    }

    result = Middleware::SecurityContext.new.call(resource)

    assert_equal resource.to_h, result.to_h
  end

  def test_raises_on_unknown_profile
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      metadata.labels = { "app.kubernetes.io/security": "yolo" }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    }

    error = assert_raises(ArgumentError) do
      Middleware::SecurityContext.new.call(resource)
    end

    assert_includes error.message, "yolo"
  end

  def test_preserves_existing_pod_security_context
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.securityContext = { runAsUser: 9999 }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    }

    result = Middleware::SecurityContext.new.call(resource)
    pod_sc = result.to_h.dig(:spec, :template, :spec, :securityContext)

    # Existing value wins
    assert_equal 9999, pod_sc[:runAsUser]
    # Middleware fills in missing values
    assert_equal true, pod_sc[:runAsNonRoot]
  end
end
