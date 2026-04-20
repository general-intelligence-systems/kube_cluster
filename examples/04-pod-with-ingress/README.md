# 04 — Pod with Ingress

A hello-world Falcon app deployed as a Pod + Service + Ingress using `PodWithIngress`, a composite `Kube::Cluster::Manifest`.

## Prerequisites

- Docker (with Compose)
- `kubectl`
- `bundle install`

## Run

```
bin/dev
```

This starts a local k3s cluster with a container registry, builds and pushes the app image, generates the Kubernetes manifest from `manifest.rb`, and applies it.

## Verify

```
kubectl logs my-app
curl -H "Host: localhost" http://localhost
```

## What it does

`manifest.rb` produces three resources from a single `PodWithIngress` declaration:

- **Pod** — runs the Falcon hello-world server on port 3000
- **Service** — routes traffic to the pod
- **Ingress** — exposes the service at `http://localhost`

## Files

| File | Purpose |
|---|---|
| `manifest.rb` | Generates Kubernetes YAML |
| `pod_with_ingress.rb` | Composite manifest: Pod + Service + Ingress |
| `config.ru` | Falcon rack app |
| `Dockerfile` | Container image |
| `docker-compose.yml` | Local k3s cluster + registry |
