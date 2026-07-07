HTTPRoute.new(
  gateway: "cia-net-https",
  domains: ['git.cia.net', 'git.kremlin.email'],
  regex:  [ '/.+/info/refs', '/.+/git-upload-pack' ],
  prefix: [ '/api', '/v2' ],
      request_header_modifier: { remove: ['...'] },
    }
  ],
  filters: {},
  services: [
    {namespace: 'default', name: 'forgejo-http', port: 3000},                                                                          
  ],
  timeouts: {...},
)

HTTPRoute::Rule.new(
)
