# HTTPRoute catalog — every Kube::Cluster['HTTPRoute'].new block in ~/infra/kremlin/ns
# 34 source files

################################################################################
# [1] ai/manifests/chrome-tool-ws.rb:42
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'chrome-tool-ws'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['chrome-tool-ws.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    backend = { group: '', kind: 'Service', name: 'chrome-tool-ws', namespace: 'ai', port: 8765, weight: 1 }
    spec.rules = [
      { # WebSocket: key-gated by the server.
        matches:     [{ path: { type: 'PathPrefix', value: '/' }, headers: [{ type: 'Exact', name: 'Upgrade', value: 'websocket' }] }],
        backendRefs: [backend],
      },
      { # REST API: key-gated by the app, not SSO.
        matches:     [{ path: { type: 'PathPrefix', value: '/api' } }],
        backendRefs: [backend],
      },
      { # Browser UI + docs: behind oauth2-proxy forward-auth.
        matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
        filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-oauth2-proxy-kremlin' } }],
        backendRefs: [backend],
      },
    ]
  }

################################################################################
# [2] ai/manifests/docuseal.rb:38
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'docuseal'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['docuseal.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'docuseal', namespace: 'ai', port: 3000, weight: 1 }],
    }]
  }

################################################################################
# [3] ai/manifests/filestash.rb:36
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'filestash'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['filestash.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-oauth2-proxy-kremlin' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'filestash', namespace: 'ai', port: 8334, weight: 1 }],
    }]
  },

################################################################################
# [4] ai/manifests/kremlin.rb:109
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'kremlin'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['kremlin.cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'kremlin', namespace: 'ai', port: 9292, weight: 1 }],
    }]
  },

################################################################################
# [5] ai/manifests/kremlin.rb:119
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'kremlin-dav'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['kremlin.cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/dav' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'kremlin', namespace: 'ai', port: 9292, weight: 1 }],
    }]
  },

################################################################################
# [6] ai/manifests/kremlin.rb:132
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'kremlin-apex'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-apex-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'kremlin', namespace: 'ai', port: 9292, weight: 1 }],
    }]
  },

################################################################################
# [7] ai/manifests/kremlin.rb:142
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'kremlin-apex-dav'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-apex-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/dav' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'kremlin', namespace: 'ai', port: 9292, weight: 1 }],
    }]
  },

################################################################################
# [8] ai/manifests/kremlin.rb:152
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'kremlin-apex-http'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-apex-http' }]
    spec.rules = [{
      matches: [{ path: { type: 'PathPrefix', value: '/' } }],
      filters: [{ type: 'RequestRedirect', requestRedirect: { scheme: 'https', statusCode: 301 } }],
    }]
  },

################################################################################
# [9] ai/manifests/kremlin.rb:167
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'kremlin-email'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-apex-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'kremlin', namespace: 'ai', port: 9292, weight: 1 }],
    }]
  },

################################################################################
# [10] ai/manifests/kremlin.rb:177
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'kremlin-email-dav'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-apex-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/dav' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'kremlin', namespace: 'ai', port: 9292, weight: 1 }],
    }]
  },

################################################################################
# [11] ai/manifests/kremlin.rb:187
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'kremlin-email-chat-manifest'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-apex-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'Exact', value: '/chat/manifest.json' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'kremlin', namespace: 'ai', port: 9292, weight: 1 }],
    }]
  },

################################################################################
# [12] ai/manifests/kremlin.rb:197
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'kremlin-email-http'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-apex-http' }]
    spec.rules = [{
      matches: [{ path: { type: 'PathPrefix', value: '/' } }],
      filters: [{ type: 'RequestRedirect', requestRedirect: { scheme: 'https', statusCode: 301 } }],
    }]
  },

################################################################################
# [13] ai/manifests/kremlin.rb:209
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'kremlin-proxy'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['proxy.cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'kremlin', namespace: 'ai', port: 4000, weight: 1 }],
    }]
  },

################################################################################
# [14] ai/manifests/supabase.rb:293
################################################################################
  Kube::Cluster["HTTPRoute"].new {
    metadata.name      = "supabase-kremlin-api"
    metadata.namespace = "kube-system"
    spec.hostnames  = ["api.kremlin.email"]
    spec.parentRefs = [{ group: "gateway.networking.k8s.io", kind: "Gateway", name: "traefik-gateway", namespace: "kube-system", sectionName: "kremlin-email-https" }]
    spec.rules = [{
      matches:     [{ path: { type: "PathPrefix", value: "/" } }],
      backendRefs: [{ group: "", kind: "Service", name: "supabase-kremlin-supabase-kong", namespace: "ai", port: 8000, weight: 1 }],
    }]
  },

################################################################################
# [15] ai/manifests/webdav.rb:116
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'webdav'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['webdav.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'webdav', namespace: 'ai', port: 8080, weight: 1 }],
    }]
  },

################################################################################
# [16] ai/manifests/webdav.rb:128
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'webdav-http'
    metadata.namespace = 'kube-system'
    spec.hostnames = ['webdav.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-http' }]
    spec.rules = [{
      matches: [{ path: { type: 'PathPrefix', value: '/' } }],
      filters: [{ type: 'RequestRedirect', requestRedirect: { scheme: 'https', statusCode: 301 } }],
    }]
  }

################################################################################
# [17] auth/manifests/authelia.rb:115
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'authelia'
    metadata.namespace = 'auth'
    spec.hostnames = ['auth.cia.net']
    spec.parentRefs = [{
      group:       'gateway.networking.k8s.io',
      kind:        'Gateway',
      name:        'traefik-gateway',
      namespace:   'kube-system',
      sectionName: 'cia-net-https',
    }]
    spec.rules = [
      # Clear-Site-Data on logout. The REAL logout is POST /api/logout (the SPA
      # button calls it); /logout is just the portal page. Both carry the header
      # so the browser wipes every cia.net cookie (authelia_session,
      # _oauth2_proxy, i_like_gitea). More specific than / so matched first.
      {
        matches: [
          { path: { type: 'PathPrefix', value: '/api/logout' } },
          { path: { type: 'PathPrefix', value: '/logout' } },
        ],
        filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'clear-site-data-cookies' } }],
        backendRefs: [{ group: '', kind: 'Service', name: 'authelia', port: 80, weight: 1 }],
      },
      {
        matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
        backendRefs: [{ group: '', kind: 'Service', name: 'authelia', port: 80, weight: 1 }],
      },
    ]
  },

################################################################################
# [18] auth/manifests/authelia.rb:147
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'authelia-public'
    metadata.namespace = 'auth'
    spec.hostnames = ['auth.kremlin.email']
    spec.parentRefs = [{
      group:       'gateway.networking.k8s.io',
      kind:        'Gateway',
      name:        'traefik-gateway',
      namespace:   'kube-system',
      sectionName: 'kremlin-email-https',
    }]
    spec.rules = [
      # Single sign-out for kremlin.email. The REAL logout is POST /api/logout
      # (the SPA button); /logout is just the portal page. Both carry
      # Clear-Site-Data so the browser wipes every kremlin.email cookie at once.
      {
        matches: [
          { path: { type: 'PathPrefix', value: '/api/logout' } },
          { path: { type: 'PathPrefix', value: '/logout' } },
        ],
        filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'clear-site-data-cookies' } }],
        backendRefs: [{ group: '', kind: 'Service', name: 'authelia', port: 80, weight: 1 }],
      },
      {
        matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
        backendRefs: [{ group: '', kind: 'Service', name: 'authelia', port: 80, weight: 1 }],
      },
    ]
  },

################################################################################
# [19] auth/manifests/authelia.rb:181
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'oauth2-proxy-kremlin'
    metadata.namespace = 'auth'
    spec.hostnames = ['auth.kremlin.email']
    spec.parentRefs = [{
      group:       'gateway.networking.k8s.io',
      kind:        'Gateway',
      name:        'traefik-gateway',
      namespace:   'kube-system',
      sectionName: 'kremlin-email-https',
    }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/oauth' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'oauth2-proxy-kremlin', port: 4180, weight: 1 }],
    }]
  },

################################################################################
# [20] auth/manifests/authelia.rb:199
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'oauth2-proxy-cia'
    metadata.namespace = 'auth'
    spec.hostnames = ['auth.cia.net']
    spec.parentRefs = [{
      group:       'gateway.networking.k8s.io',
      kind:        'Gateway',
      name:        'traefik-gateway',
      namespace:   'kube-system',
      sectionName: 'cia-net-https',
    }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/oauth' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'oauth2-proxy-cia', port: 4180, weight: 1 }],
    }]
  },

################################################################################
# [21] default/manifests/argo.rb:126
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'argo'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['argo.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'argo-workflows-server', namespace: 'default', port: 2746, weight: 1 }],
    }]
  },

################################################################################
# [22] default/manifests/forgejo.rb:36
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'forgejo'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['git.cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
    spec.rules = [
      # Skip forgejo's local login form: send /user/login straight to the authelia
      # OIDC handshake. Exact match (more specific than the `/` rule, wins
      # regardless of order). RequestRedirect is terminal -- no backend needed.
      {
        matches: [{ path: { type: 'Exact', value: '/user/login' } }],
        filters: [{
          type: 'RequestRedirect',
          requestRedirect: {
            scheme:     'https',
            path:       { type: 'ReplaceFullPath', replaceFullPath: '/user/oauth2/authelia' },
            statusCode: 302,
          },
        }],
      },
      # Logout: hit forgejo (clears i_like_gitea) AND tag the response with
      # Clear-Site-Data so the browser wipes every cia.net cookie -> single
      # sign-out. No forward-auth here so oauth2-proxy doesn't re-set its cookie
      # on the same response.
      {
        backendRefs: [{ group: '', kind: 'Service', name: 'forgejo-http', namespace: 'default', port: 3000, weight: 1 }],
        matches:     [{ path: { type: 'Exact', value: '/user/logout' } }],
        filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'clear-site-data-cookies' } }],
      },
      # Everything else: oauth2-proxy forward-auth establishes the shared authelia
      # session; forgejo then OIDC-logs-in silently against it (see HelmChart).
      {
        backendRefs: [{ group: '', kind: 'Service', name: 'forgejo-http', namespace: 'default', port: 3000, weight: 1 }],
        matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
        filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-oauth2-proxy-cia' } }],
      },
    ]
  },

################################################################################
# [23] default/manifests/forgejo.rb:75
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'forgejo-git'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['git.cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: 'forgejo-http', namespace: 'default', port: 3000, weight: 1 }],
      matches: [
        { path: { type: 'RegularExpression', value: '/.+/info/refs' } },
        { path: { type: 'RegularExpression', value: '/.+/git-upload-pack' } },
        { path: { type: 'RegularExpression', value: '/.+/git-receive-pack' } },
        { path: { type: 'PathPrefix', value: '/api' } },
        { path: { type: 'PathPrefix', value: '/v2' } },
      ],
      timeouts: { request: '600s', backendRequest: '600s' }
    }]
  },

################################################################################
# [24] default/manifests/forgejo.rb:93
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'forgejo-git-http'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['git.cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-http' }]
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: 'forgejo-http', namespace: 'default', port: 3000, weight: 1 }],
      matches: [
        { path: { type: 'RegularExpression', value: '/.+/info/refs' } },
        { path: { type: 'RegularExpression', value: '/.+/git-upload-pack' } },
        { path: { type: 'RegularExpression', value: '/.+/git-receive-pack' } },
        { path: { type: 'PathPrefix', value: '/api' } },
        { path: { type: 'PathPrefix', value: '/v2' } },
      ],
      timeouts: { request: '600s', backendRequest: '600s' }
    }]
  },

################################################################################
# [25] default/manifests/gateway.rb:7
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'caldav'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['caldav.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: 'caldav', namespace: 'default', port: 9292, weight: 1 }],
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-authelia-basic' } }]
    }]
  }

################################################################################
# [26] default/manifests/killbill.rb:321
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'kaui'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['billing.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: 'kaui', namespace: 'default', port: 8080, weight: 1 }],
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-oauth2-proxy-kremlin' } }]
    }]
  }

################################################################################
# [27] default/manifests/miniflux.rb:42
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'miniflux'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['rss.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    # No gateway forward-auth: miniflux authenticates itself (local admin + OIDC
    # against authelia), so a second SSO layer here would double-prompt.
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: 'miniflux', namespace: 'default', port: 8080, weight: 1 }],
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }]
    }]
  },

################################################################################
# [28] default/manifests/operaton.rb:446
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'operaton'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['operaton.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-oauth2-proxy-kremlin' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'operaton', namespace: 'default', port: 8080, weight: 1 }],
    }]
  },

################################################################################
# [29] default/manifests/plasmic.rb:29
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'plasmic'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['plasmic.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      # Route to the nginx front tier (serves the SPA shell with client-side
      # routing fallback and proxies /api, /socket.io, /static to the wab app).
      backendRefs: [{ group: '', kind: 'Service', name: 'plasmic-web', namespace: 'default', port: 80, weight: 1 }],
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }]
    }]
  },

################################################################################
# [30] default/manifests/plasmic.rb:123
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'plasmic-codegen'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['codegen.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: 'plasmic-codegen', namespace: 'default', port: 3004, weight: 1 }],
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }]
    }]
  },

################################################################################
# [31] default/manifests/plasmic.rb:248
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'plasmic-host'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['plasmic-host.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: 'plasmic-host', namespace: 'default', port: 80, weight: 1 }],
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }]
    }]
  }

################################################################################
# [32] docker-registry/manifests.rb:147
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'docker-registry'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['registry.cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
    spec.rules = [
      {
        matches:     [{ path: { type: 'PathPrefix', value: '/v2/' } }],
        backendRefs: [{ group: '', kind: 'Service', name: 'docker-registry', namespace: 'docker-registry', port: 5000, weight: 1 }],
      },
      {
        matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
        filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-oauth2-proxy-cia' } }],
        backendRefs: [{ group: '', kind: 'Service', name: 'docker-registry', namespace: 'docker-registry', port: 80, weight: 1 }],
      },
    ]
  },

################################################################################
# [33] firefly/manifests.rb:214
################################################################################
  Kube::Cluster["HTTPRoute"].new {
    metadata.name = "firefly"
    spec.hostnames = ["firefly.kremlin.email"]
    spec.parentRefs = [{ group: "gateway.networking.k8s.io", kind: "Gateway", name: "traefik-gateway", namespace: "kube-system", sectionName: "kremlin-email-https" }]
    spec.rules = [{
      matches: [{
        path: {
          type: "PathPrefix",
          value: "/"
        }
      }],
      backendRefs: [{
        name: "firefly",
        port: 8080,
        weight: 1,
      }]
    }]
  },

################################################################################
# [34] fusion-pbx/manifests.rb:25
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'fusion-pbx'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['pbx.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: 'fusion-pbx-web', namespace: 'fusion-pbx', port: 443, weight: 1 }],
      matches: [{ path: { type: 'PathPrefix', value: '/' } }],
      filters: [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-oauth2-proxy-kremlin' } }]
    }]
  },

################################################################################
# [35] fusion-pbx/manifests.rb:37
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'fusion-pbx-http'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['pbx.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-http' }]
    spec.rules = [{
      filters: [{ type: 'RequestRedirect', requestRedirect: { scheme: 'https', statusCode: 301 } }],
      matches: [{ path: { type: 'PathPrefix', value: '/' } }]
    }]
  },

################################################################################
# [36] fusion-pbx/manifests.rb:49
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'fusionpbx-postgrest'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['pbx-api.cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: 'fusionpbx-postgrest', namespace: 'fusion-pbx', port: 3000, weight: 1 }],
      matches: [{ path: { type: 'PathPrefix', value: '/' } }],
      filters: [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-token' } }]
    }]
  },

################################################################################
# [37] jambonz/manifests.rb:21
################################################################################
  https = Kube::Cluster['HTTPRoute'].new {
    metadata.name      = entry[:name]
    metadata.namespace = 'kube-system'
    spec.hostnames  = [entry[:host]]
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway',
                         name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: entry[:service], namespace: 'jambonz', port: entry[:port], weight: 1 }],
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
    }]
  }

################################################################################
# [38] jambonz/manifests.rb:33
################################################################################
  http = Kube::Cluster['HTTPRoute'].new {
    metadata.name      = "#{slug}-http"
    metadata.namespace = 'kube-system'
    spec.hostnames  = [entry[:host]]
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway',
                         name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-http' }]
    spec.rules = [{
      filters: [{ type: 'RequestRedirect', requestRedirect: { scheme: 'https', statusCode: 301 } }],
      matches: [{ path: { type: 'PathPrefix', value: '/' } }],
    }]
  }

################################################################################
# [39] kube-system/manifests/airbyte.rb:51
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'airbyte'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['airbyte.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-oauth2-proxy-kremlin' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'airbyte-airbyte-server-svc', namespace: 'ai', port: 8001, weight: 1 }],
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }]
    }]
  },

################################################################################
# [40] kube-system/manifests/flux-cd.rb:222
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'flux-operator'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['flux.cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-oauth2-proxy-cia' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'flux-operator', namespace: 'flux-system', port: 9080, weight: 1 }],
    }]
  },

################################################################################
# [41] kube-system/manifests/headlamp.rb:71
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'headlamp'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['headlamp.cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
    spec.rules = [{
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-oauth2-proxy-cia' } }],
      backendRefs: [{ group: '', kind: 'Service', name: 'headlamp', namespace: 'default', port: 80, weight: 1 }],
    }]
  },

################################################################################
# [42] kube-system/manifests/supabase.rb:69
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'supabase'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['supabase.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: 'supabase-supabase-kong', namespace: 'default', port: 8000, weight: 1 }],
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }]
    }]
  },

################################################################################
# [43] kube-system/manifests/sure.rb:104
################################################################################
  Kube::Cluster["HTTPRoute"].new {
    metadata.name = "sure"
    metadata.namespace = "sure"
    spec.hostnames = ["sure.kremlin.email"]
    spec.parentRefs = [{ group: "gateway.networking.k8s.io", kind: "Gateway", name: "traefik-gateway", namespace: "kube-system", sectionName: "kremlin-email-https" }]
    spec.rules = [{
      matches: [{
        path: {
          type: "PathPrefix",
          value: "/"
        }
      }],
      backendRefs: [{
        name: "sure",
        port: 80,
        weight: 1,
      }]
    }]
  },

################################################################################
# [44] mail/manifests/integration_center.rb:100
################################################################################
  Kube::Cluster["HTTPRoute"].new {
    metadata.name = "integration-center"
    spec.hostnames = ["integrations.kremlin.email"]
    spec.parentRefs = [{ group: "gateway.networking.k8s.io", kind: "Gateway",
                         name: "traefik-gateway", namespace: "kube-system",
                         sectionName: "kremlin-email-https" }]
    spec.rules = [{
      matches:     [{ path: { type: "PathPrefix", value: "/" } }],
      # Gate the whole app behind an auth.kremlin.email session: it manages OAuth
      # tokens, so it must never be reachable unauthenticated. The app's own
      # Google/GitHub OAuth connect flow runs *inside*, after this gate.
      filters:     [{ type: "ExtensionRef", extensionRef: { group: "traefik.io", kind: "Middleware", name: "forwardauth-oauth2-proxy-kremlin" } }],
      backendRefs: [{ name: "integration-center", port: 9292, weight: 1 }],
    }]
  },

################################################################################
# [45] mail/manifests/integration_center.rb:117
################################################################################
  Kube::Cluster["HTTPRoute"].new {
    metadata.name = "integration-center-http"
    spec.hostnames = ["integrations.kremlin.email"]
    spec.parentRefs = [{ group: "gateway.networking.k8s.io", kind: "Gateway",
                         name: "traefik-gateway", namespace: "kube-system",
                         sectionName: "kremlin-email-http" }]
    spec.rules = [{
      matches: [{ path: { type: "PathPrefix", value: "/" } }],
      filters: [{ type: "RequestRedirect", requestRedirect: { scheme: "https", statusCode: 301 } }],
    }]
  },

################################################################################
# [46] mail/manifests/mailpit.rb:15
################################################################################
  Kube::Cluster["HTTPRoute"].new {
    metadata.name = "mailpit"
    spec.hostnames = ["mailpit.kremlin.email"]
    spec.parentRefs = [{ group: "gateway.networking.k8s.io", kind: "Gateway", name: "traefik-gateway", namespace: "kube-system", sectionName: "kremlin-email-https" }]
    spec.rules = [{
      matches: [{ path: { type: "PathPrefix", value: "/" } }],
      # Require an auth.kremlin.email session -- mailpit exposes every captured
      # email, so it must not be world-readable.
      filters: [{ type: "ExtensionRef", extensionRef: { group: "traefik.io", kind: "Middleware", name: "forwardauth-oauth2-proxy-kremlin" } }],
      backendRefs: [{ name: "mailpit", port: 8025, weight: 1 }],
    }]
  },

################################################################################
# [47] mail/manifests/sogo.rb:128
################################################################################
  Kube::Cluster["HTTPRoute"].new {
    metadata.name = "sogo"
    spec.hostnames = ["sogo.kremlin.email"]
    spec.parentRefs = [{ group: "gateway.networking.k8s.io", kind: "Gateway", name: "traefik-gateway", namespace: "kube-system", sectionName: "kremlin-email-https" }]
    spec.rules = [{
      matches: [{ path: { type: "PathPrefix", value: "/" } }],
      # SOGoTrustProxyAuthentication is on, so strip any client-supplied
      # remote-user header on the public edge — only the in-cluster Rails proxy
      # (which never traverses this route) is allowed to assert it. Prevents an
      # external client from forging X-WebObjects-Remote-User to impersonate.
      filters: [{
        type: "RequestHeaderModifier",
        requestHeaderModifier: { remove: ["x-webobjects-remote-user"] },
      }],
      backendRefs: [{ name: "sogo", port: 80, weight: 1 }],
    }]
  },

################################################################################
# [48] metrics/manifests.rb:21
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'hubble'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['hubble.cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: 'hubble-ui', namespace: 'kube-system', port: 80, weight: 1 }],
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-oauth2-proxy-cia' } }],
    }]
  },

################################################################################
# [49] metrics/manifests.rb:211
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'perses'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['perses.cia.net']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: 'perses', namespace: 'metrics', port: 8080, weight: 1 }],
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-oauth2-proxy-cia' } }],
    }]
  },

################################################################################
# [50] movies/manifests.rb:76
################################################################################
    Kube::Cluster['HTTPRoute'].new {
      metadata.name      = 'jellyfin'
      metadata.namespace = 'kube-system'
      spec.hostnames  = ['movies.cia.net']
      spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
      spec.rules = [{
        backendRefs: [{ group: '', kind: 'Service', name: 'jellyfin', namespace: 'movies', port: 8096, weight: 1 }],
        matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      }]
    },

################################################################################
# [51] movies/manifests.rb:116
################################################################################
    Kube::Cluster['HTTPRoute'].new {
      metadata.name      = 'seerr'
      metadata.namespace = 'kube-system'
      spec.hostnames  = ['seerr.cia.net']
      spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
      spec.rules = [{
        backendRefs: [{ group: '', kind: 'Service', name: 'seerr', namespace: 'movies', port: 5055, weight: 1 }],
        matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      }]
    },

################################################################################
# [52] movies/manifests.rb:158
################################################################################
    Kube::Cluster['HTTPRoute'].new {
      metadata.name      = 'radarr'
      metadata.namespace = 'kube-system'
      spec.hostnames  = ['radarr.cia.net']
      spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
      spec.rules = [{
        backendRefs: [{ group: '', kind: 'Service', name: 'radarr', namespace: 'movies', port: 7878, weight: 1 }],
        matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      }]
    },

################################################################################
# [53] movies/manifests.rb:199
################################################################################
    Kube::Cluster['HTTPRoute'].new {
      metadata.name      = 'sonarr'
      metadata.namespace = 'kube-system'
      spec.hostnames  = ['sonarr.cia.net']
      spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'cia-net-https' }]
      spec.rules = [{
        backendRefs: [{ group: '', kind: 'Service', name: 'sonarr', namespace: 'movies', port: 8989, weight: 1 }],
        matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      }]
    },

################################################################################
# [54] passbolt/manifests.rb:25
################################################################################
  Kube::Cluster["HTTPRoute"].new {
    metadata.name = "passbolt"
    spec.hostnames = ["passbolt.kremlin.email"]
    spec.parentRefs = [{ group: "gateway.networking.k8s.io", kind: "Gateway", name: "traefik-gateway", namespace: "kube-system", sectionName: "kremlin-email-https" }]

    spec.rules = [{
      matches: [{
        path: {
          type: "PathPrefix",
          value: "/"
        }
      }],
      backendRefs: [{
        name: "passbolt",
        port: 8080,
        weight: 1,
      }]
    }]
  },

################################################################################
# [55] production/manifests.rb:256
################################################################################
      Kube::Cluster['HTTPRoute'].new {
        metadata.name      = "tradeportal-production-#{slug}"
        metadata.namespace = 'kube-system'
        spec.hostnames  = [host]
        spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: "#{section}-https" }]
        spec.rules = [{
          backendRefs: [{ group: '', kind: 'Service', name: 'web', namespace: 'production', port: 3000, weight: 1 }],
          matches: [{ path: { type: 'PathPrefix', value: '/' } }]
        }]
      },

################################################################################
# [56] production/manifests.rb:267
################################################################################
      Kube::Cluster['HTTPRoute'].new {
        metadata.name      = "tradeportal-production-#{slug}-http"
        metadata.namespace = 'kube-system'
        spec.hostnames  = [host]
        spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: "#{slug}-http" }]
        spec.rules = [{
          filters: [{ type: 'RequestRedirect', requestRedirect: { scheme: 'https', statusCode: 301 } }],
          matches: [{ path: { type: 'PathPrefix', value: '/' } }]
        }]
      },

################################################################################
# [57] production/manifests.rb:279
################################################################################
      Kube::Cluster['HTTPRoute'].new {
        metadata.name      = "tradeportal-production-cable-#{slug}"
        metadata.namespace = 'production'
        spec.hostnames  = [host]
        spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: "#{section}-https" }]
        spec.rules = [{
          backendRefs: [{ group: '', kind: 'Service', name: 'anycable-go', namespace: 'production', port: 8080, weight: 1 }],
          matches: [{ path: { type: 'PathPrefix', value: '/cable' } }]
        }]
      },

################################################################################
# [58] production/manifests/supabase.rb:244
################################################################################
  Kube::Cluster["HTTPRoute"].new {
    metadata.name      = "supabase-tradeportal-api"
    metadata.namespace = "kube-system"
    spec.hostnames  = ["api.tradeportal.pro"]
    spec.parentRefs = [{ group: "gateway.networking.k8s.io", kind: "Gateway", name: "traefik-gateway", namespace: "kube-system", sectionName: "api-tradeportal-pro-https" }]
    spec.rules = [{
      matches:     [{ path: { type: "PathPrefix", value: "/" } }],
      backendRefs: [{ group: "", kind: "Service", name: "supabase-tradeportal-supabase-kong", namespace: "production", port: 8000, weight: 1 }],
    }]
  },

################################################################################
# [59] shared/manifests/skyvern.rb:115
################################################################################
  Kube::Cluster["HTTPRoute"].new {
    metadata.name = "skyvern"
    spec.hostnames = ["skyvern.kremlin.email"]
    spec.parentRefs = [{ group: "gateway.networking.k8s.io", kind: "Gateway", name: "traefik-gateway", namespace: "kube-system", sectionName: "kremlin-email-https" }]
    spec.rules = [
      { matches: [{ path: { type: "PathPrefix", value: "/api" } }],
        backendRefs: [{ name: "skyvern-backend", port: 8000, weight: 1 }] },
      { matches: [{ path: { type: "PathPrefix", value: "/v1" } }],
        backendRefs: [{ name: "skyvern-backend", port: 8000, weight: 1 }] },
      { matches: [{ path: { type: "PathPrefix", value: "/artifacts" } }],
        backendRefs: [{ name: "skyvern-frontend", port: 9090, weight: 1 }] },
      { matches: [{ path: { type: "PathPrefix", value: "/" } }],
        backendRefs: [{ name: "skyvern-frontend", port: 8080, weight: 1 }] },
    ]
  },

################################################################################
# [60] sourcebot/manifests.rb:97
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'sourcebot'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['sg.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-https' }]
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: 'sourcebot', namespace: 'sourcebot', port: 3000, weight: 1 }],
      matches:     [{ path: { type: 'PathPrefix', value: '/' } }],
      filters:     [{ type: 'ExtensionRef', extensionRef: { group: 'traefik.io', kind: 'Middleware', name: 'forwardauth-oauth2-proxy-kremlin' } }],
    }]
  },

################################################################################
# [61] sourcebot/manifests.rb:109
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = 'sourcebot-http'
    metadata.namespace = 'kube-system'
    spec.hostnames  = ['sg.kremlin.email']
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: 'kremlin-email-http' }]
    spec.rules = [{
      filters: [{ type: 'RequestRedirect', requestRedirect: { scheme: 'https', statusCode: 301 } }],
      matches: [{ path: { type: 'PathPrefix', value: '/' } }],
    }]
  },

################################################################################
# [62] staging/manifests.rb:202
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = "tradeportal-staging-#{STAGING_SLUG}"
    metadata.namespace = 'kube-system'
    spec.hostnames  = [STAGING_HOST]
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: "#{STAGING_SECTION}-https" }]
    spec.rules = [{
      backendRefs: [{ group: '', kind: 'Service', name: 'web', namespace: 'staging', port: 3000, weight: 1 }],
      matches: [{ path: { type: 'PathPrefix', value: '/' } }]
    }]
  },

################################################################################
# [63] staging/manifests.rb:213
################################################################################
  Kube::Cluster['HTTPRoute'].new {
    metadata.name      = "tradeportal-staging-#{STAGING_SLUG}-http"
    metadata.namespace = 'kube-system'
    spec.hostnames  = [STAGING_HOST]
    spec.parentRefs = [{ group: 'gateway.networking.k8s.io', kind: 'Gateway', name: 'traefik-gateway', namespace: 'kube-system', sectionName: "#{STAGING_SECTION}-http" }]
    spec.rules = [{
      filters: [{ type: 'RequestRedirect', requestRedirect: { scheme: 'https', statusCode: 301 } }],
      matches: [{ path: { type: 'PathPrefix', value: '/' } }]
    }]
  },

