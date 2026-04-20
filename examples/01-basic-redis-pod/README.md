# 01 — Basic Redis Pod

A single Redis pod defined with `Kube::Cluster['Pod']`, demonstrating the resource DSL and block overrides.

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
kubectl logs my-redis-1
kubectl exec -it my-redis-1 -- redis-cli ping
```

## Files

| File | Purpose |
|---|---|
| `manifest.rb` | Defines `RedisPod` class and generates YAML |
| `redis.conf` | Redis config mounted into the pod |
| `docker-compose.yml` | Local k3s cluster |
