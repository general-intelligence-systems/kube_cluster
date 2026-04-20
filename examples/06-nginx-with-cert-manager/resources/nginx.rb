# frozen_string_literal: true

class Nginx < Kube::Cluster::Manifest
  def initialize(name:, host:, &block)
    ns          = name
    match_labels = { app: name }

    super(
      Kube::Cluster["Namespace"].new {
        metadata.name   = ns
        metadata.labels = match_labels
      },

      Kube::Cluster["ConfigMap"].new {
        metadata.name      = "#{name}-config"
        metadata.namespace = ns
        metadata.labels    = match_labels

        self.data = {
          "default.conf" => <<~NGINX,
            server {
                listen 80;
                server_name _;

                location / {
                    root   /usr/share/nginx/html;
                    index  index.html;
                }

                location /healthz {
                    access_log off;
                    return 200 "ok\\n";
                    add_header Content-Type text/plain;
                }
            }
          NGINX

          "index.html" => <<~HTML,
            <!DOCTYPE html>
            <html>
            <head><title>Hello from Nginx</title></head>
            <body>
                <h1>Hello from Nginx with TLS!</h1>
                <p>Certificates managed by cert-manager.</p>
            </body>
            </html>
          HTML
        }
      },

      Kube::Cluster["Deployment"].new {
        metadata.name      = name
        metadata.namespace = ns
        metadata.labels    = match_labels

        spec.replicas = 2
        spec.selector.matchLabels = match_labels

        spec.template.metadata.labels = match_labels
        spec.template.spec.containers = [
          {
            name:  name,
            image: "nginx:1.27-alpine",
            ports: [
              { name: "http", containerPort: 80, protocol: "TCP" },
            ],
            resources: {
              requests: { cpu: "50m",  memory: "64Mi" },
              limits:   { cpu: "200m", memory: "128Mi" },
            },
            volumeMounts: [
              { name: "nginx-config", mountPath: "/etc/nginx/conf.d", readOnly: true },
              { name: "nginx-html",   mountPath: "/usr/share/nginx/html", readOnly: true },
            ],
            livenessProbe: {
              httpGet: { path: "/healthz", port: "http" },
              initialDelaySeconds: 5,
              periodSeconds: 10,
            },
            readinessProbe: {
              httpGet: { path: "/healthz", port: "http" },
              initialDelaySeconds: 2,
              periodSeconds: 5,
            },
          },
        ]

        spec.template.spec.volumes = [
          {
            name: "nginx-config",
            configMap: {
              name:  "#{name}-config",
              items: [{ key: "default.conf", path: "default.conf" }],
            },
          },
          {
            name: "nginx-html",
            configMap: {
              name:  "#{name}-config",
              items: [{ key: "index.html", path: "index.html" }],
            },
          },
        ]
      },

      Kube::Cluster["Service"].new {
        metadata.name      = name
        metadata.namespace = ns
        metadata.labels    = match_labels

        spec.selector = match_labels
        spec.ports = [
          { name: "http", port: 80, targetPort: "http", protocol: "TCP" },
        ]
      },

      Kube::Cluster["Ingress"].new {
        metadata.name      = name
        metadata.namespace = ns
        metadata.labels    = match_labels
        metadata.annotations = {
          "cert-manager.io/cluster-issuer": "selfsigned",
        }

        spec.ingressClassName = "traefik"
        spec.tls = [
          {
            hosts:      [host],
            secretName: "#{name}-tls",
          },
        ]
        spec.rules = [
          {
            host: host,
            http: {
              paths: [
                {
                  path:     "/",
                  pathType: "Prefix",
                  backend: {
                    service: {
                      name: name,
                      port: { name: "http" },
                    },
                  },
                },
              ],
            },
          },
        ]
      },
    )

    instance_exec(&block) if block
  end
end
