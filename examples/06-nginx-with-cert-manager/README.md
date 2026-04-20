# 06 — Nginx with cert-manager

Deploys a stock **nginx** Deployment (configured via ConfigMap) with a self-signed TLS certificate from **cert-manager**. Uses k3s's built-in Traefik as the ingress controller.

## Architecture

```
Internet
  │
  ▼
┌─────────────────────────────────────┐
│  Traefik (k3s built-in)             │  ← terminates TLS
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Ingress → Service → Deployment    │  ← nginx:1.27-alpine
│  nginx-app namespace                │
└─────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  cert-manager (Helm)                │  ← provisions self-signed cert
│  ClusterIssuer (selfsigned)         │
└─────────────────────────────────────┘
```

## Prerequisites

- Docker (with Compose)
- `helm` CLI installed
- `kubectl`
- `bundle install`

## Run

```
bin/dev
```

## Verify

```
kubectl get pods -n nginx-app
kubectl get ingress -n nginx-app
kubectl get certificate -n nginx-app
curl -H "Host: app.example.com" http://localhost
```

## Files

| File | Purpose |
|---|---|
| `manifest.rb` | Assembles cert-manager chart + application resources |
| `nginx_app.rb` | `NginxApp` — Namespace + ConfigMap + Deployment + Service + Ingress |
| `self_signed_issuer.rb` | `SelfSignedIssuer` — self-signed ClusterIssuer |
| `docker-compose.yml` | Local k3s cluster |
