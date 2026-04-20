# 02 — Manifest with Middleware

A full app deployment (Deployment, Service, Ingress, ConfigMap, HPA) assembled with `Kube::Cluster::Manifest` and transformed by middleware (Namespace, Labels).

## Prerequisites

- Docker (with Compose)
- `kubectl`
- `bundle install` (from project root)

## Run

```
bin/dev
```

## Verify

```
kubectl get pods -n my-app
kubectl logs -n my-app -l app=my-app
curl -H "Host: app.example.com" http://localhost
```

## Files

| File | Purpose |
|---|---|
| `manifest.rb` | Assembles resources and applies middleware |
| `templates/` | Resource classes (Deployment, Service, Ingress, ConfigMap, HPA) |
| `middleware/` | Namespace and Labels middleware |
| `config.ru` | Falcon hello-world app |
| `Dockerfile` | Container image |
| `docker-compose.yml` | Local k3s cluster + registry |
