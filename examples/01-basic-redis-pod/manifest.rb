require "bundler/setup"
require "kube/cluster"

class RedisPod < Kube::Cluster['Pod']
  def initialize(container_name: 'my-redis-container', **options, &block)
    super {
      spec.containers = [
        {
          name: container_name,
          image: 'redis:8.0.2',

          command: ["redis-server", "/redis-master/redis.conf"],
          env:     [{name: 'MASTER', value: "true"}],
          ports:   [{ containerPort: 6379 }],

          resources: { limits: { cpu: "0.1" } },
          volumeMounts: [
            { mountPath: '/redis-master-data', name: 'data' },
            { mountPath: '/redis-master', name: 'config' },
          ]
        }
      ]

      spec.volumes = [
        {
          name: 'data',
          emptyDir: {}
        },
        {
          name: 'config',
          configMap: {
            name: 'example-redis-config',
            items: [ { key: 'redis-config', path: 'redis.conf' } ]
          }
        },
      ]
    }
    instance_exec(&block) if block_given?
  end
end

puts RedisPod.new(
  container_name: 'my-redis-container-1',
  metadata: {
    namespace: 'my-namespace'
  }
).to_yaml

puts RedisPod.new(container_name: 'my-redis-container-1') {
  metadata.namespace = 'my-namespace'
}.to_yaml

puts RedisPod.new {
  metadata.namespace = "my-namespace"
}.to_yaml

puts RedisPod.new {
  metadata.name = "my-redis-1"
  metadata.namespace = "my-namespace"
}.to_yaml
