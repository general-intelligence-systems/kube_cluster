# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module GatewayApi
        # A single-rule HTTPRoute attached to the cluster's one traefik-gateway.
        #
        # Every route in ns/ shares the same parentRefs (the `traefik-gateway`
        # in kube-system) and differs only by listener section, host(s), the
        # backing Service, the path matches, and an optional chain of traefik
        # middlewares. This collapses that boilerplate to a keyword call.
        #
        # Deliberately models exactly ONE rule: one set of matches -> one
        # backend (or a terminal redirect), with one filter chain. Routes that
        # need distinct backends or filters per path (fanout) are expressed as
        # several instances on the same host -- the gateway merges them and the
        # more-specific match wins.
        #
        #   Standard::GatewayApi::HTTPRoute.new(
        #     name:    "sourcebot",
        #     gateway: "example-com-https",
        #     domains: ["sg.example.com"],
        #     service: { namespace: "sourcebot", name: "sourcebot", port: 3000 },
        #     middleware: "forwardauth-oauth2-proxy-example",
        #   )
        #
        # Many matches -> one backend (forgejo git smart-HTTP):
        #
        #   Standard::GatewayApi::HTTPRoute.new(
        #     name: "forgejo-git", gateway: "example-net-https", domains: ["git.example.net"],
        #     regex:  ["/.+/info/refs", "/.+/git-upload-pack", "/.+/git-receive-pack"],
        #     prefix: ["/api", "/v2"],
        #     service: { namespace: "default", name: "forgejo-http", port: 3000 },
        #     timeouts: { request: "600s", backendRequest: "600s" },
        #   )
        #
        # Terminal http->https redirect (the `-http` sibling):
        #
        #   Standard::GatewayApi::HTTPRoute.new(
        #     name: "sourcebot-http", gateway: "example-com-http",
        #     domains: ["sg.example.com"], prefix: ["/"], redirect: true,
        #   )
        class HTTPRoute < Kube::Cluster["HTTPRoute"]
          GATEWAY_GROUP = "gateway.networking.k8s.io"
          GATEWAY_NAME  = "traefik-gateway"
          GATEWAY_NS    = "kube-system"

          # traefik middlewares are attached to a rule via an ExtensionRef filter.
          MIDDLEWARE_GROUP = "traefik.io"
          MIDDLEWARE_KIND  = "Middleware"

          PATH_TYPES = {
            prefix: "PathPrefix",
            exact:  "Exact",
            regex:  "RegularExpression",
          }.freeze

          def initialize(
            name:,
            gateway:,
            domains:,
            service:         nil,
            prefix:          nil,
            exact:           nil,
            regex:           nil,
            headers:         nil,
            middleware:      nil,
            redirect:        nil,
            header_modifier: nil,
            timeouts:        nil,
            namespace:       "kube-system",
            &block
          )
            hostnames = Array(domains)
            matches   = _matches(prefix: prefix, exact: exact, regex: regex, headers: headers)
            filters   = _filters(middleware: middleware, redirect: redirect, header_modifier: header_modifier)

            rule = { matches: matches }
            rule[:filters]     = filters                unless filters.empty?
            rule[:backendRefs] = [_backend(service)]    if service
            rule[:timeouts]    = timeouts               if timeouts

            super() {
              metadata.name      = name
              # A co-located route (namespace: nil) omits metadata.namespace so
              # it lands in whatever namespace applies it; cross-namespace routes
              # in kube-system set it explicitly.
              metadata.namespace = namespace if namespace

              spec.hostnames  = hostnames
              spec.parentRefs = [{
                group:       GATEWAY_GROUP,
                kind:        "Gateway",
                name:        GATEWAY_NAME,
                namespace:   GATEWAY_NS,
                sectionName: gateway,
              }]
              spec.rules = [rule]

              instance_exec(&block) if block_given?
            }
          end

          private

          # Build the rule's `matches`: one entry per path across the typed
          # arrays, all sharing the single backend. A path match is mandatory --
          # every route (including a redirect-only one) must state its path, so
          # this raises rather than silently assuming `/` when none is given.
          def _matches(prefix:, exact:, regex:, headers:)
            entries = []
            { prefix: prefix, exact: exact, regex: regex }.each do |kind, values|
              Array(values).each do |value|
                entries << { path: { type: PATH_TYPES.fetch(kind), value: value } }
              end
            end
            if entries.empty?
              raise ArgumentError,
                    "HTTPRoute requires at least one path match: pass prefix:, exact:, or regex:"
            end

            hdrs = _headers(headers)
            hdrs.empty? ? entries : entries.map { |m| m.merge(headers: hdrs) }
          end

          # Accepts either a { "Header" => "value" } hash (Exact match) or a
          # ready-made array of Gateway API header-match hashes.
          def _headers(headers)
            return [] if headers.nil? || headers.empty?
            return headers if headers.is_a?(Array)

            headers.map { |name, value| { type: "Exact", name: name.to_s, value: value } }
          end

          # Filter chain. Order: header rewrite, then middleware(s), then a
          # terminal redirect (which needs no backend).
          def _filters(middleware:, redirect:, header_modifier:)
            filters = []

            if header_modifier
              filters << { type: "RequestHeaderModifier", requestHeaderModifier: header_modifier }
            end

            Array(middleware).each do |name|
              filters << {
                type:         "ExtensionRef",
                extensionRef: { group: MIDDLEWARE_GROUP, kind: MIDDLEWARE_KIND, name: name },
              }
            end

            if redirect
              filters << { type: "RequestRedirect", requestRedirect: _redirect(redirect) }
            end

            filters
          end

          # `redirect: true` is the common http->https 301. A hash customises
          # scheme / status / path (ReplaceFullPath) / hostname.
          def _redirect(redirect)
            opts = redirect == true ? {} : redirect

            rr = {
              scheme:     opts.fetch(:scheme, "https"),
              statusCode: opts[:status] || opts[:statusCode] || 301,
            }
            rr[:path]     = { type: "ReplaceFullPath", replaceFullPath: opts[:path] } if opts[:path]
            rr[:hostname] = opts[:hostname] if opts[:hostname]
            rr
          end

          # backendRef in the convention's field order. The Service `namespace`
          # is emitted only when the route lives in a different namespace than
          # the backend (the cross-namespace model, which needs a ReferenceGrant
          # the caller supplies). Omitting it yields the co-located short form.
          def _backend(service)
            ref = {}
            # Cross-namespace backends carry the explicit group/kind/namespace
            # (and need a ReferenceGrant); a co-located Service uses the bare
            # short form. Emitting group/kind only in the former keeps both
            # shapes byte-identical to the hand-written routes they replace.
            if service[:namespace]
              ref[:group]     = ""
              ref[:kind]      = "Service"
              ref[:name]      = service.fetch(:name)
              ref[:namespace] = service[:namespace]
            else
              ref[:name] = service.fetch(:name)
            end
            ref[:port]   = service.fetch(:port)
            ref[:weight] = service.fetch(:weight, 1)
            ref
          end
        end
      end
    end
  end
end

__END__

describe "GatewayApi::HTTPRoute" do
  route = proc { |**kw| Kube::Cluster::Standard::GatewayApi::HTTPRoute.new(**kw) }

  it "initializes without error" do
    route.(
      name:    "docuseal",
      gateway: "example-com-https",
      domains: ["docuseal.example.com"],
      prefix:  ["/"],
      service: { namespace: "ai", name: "docuseal", port: 3000 },
    ).to_yaml.is_a?(String).should == true
  end

  it "wires the fixed traefik-gateway parentRef with the given section" do
    yaml = route.(
      name:    "docuseal",
      gateway: "example-com-https",
      domains: ["docuseal.example.com"],
      prefix:  ["/"],
      service: { namespace: "ai", name: "docuseal", port: 3000 },
    ).to_yaml

    yaml.should.include "traefik-gateway"
    yaml.should.include "example-com-https"
    yaml.should.include "docuseal.example.com"
    yaml.should.include "PathPrefix"
  end

  it "renders many typed matches onto one backend with timeouts" do
    yaml = route.(
      name:    "forgejo-git",
      gateway: "example-net-https",
      domains: ["git.example.net"],
      regex:   ["/.+/info/refs", "/.+/git-upload-pack", "/.+/git-receive-pack"],
      prefix:  ["/api", "/v2"],
      service: { namespace: "default", name: "forgejo-http", port: 3000 },
      timeouts: { request: "600s", backendRequest: "600s" },
    ).to_yaml

    yaml.should.include "RegularExpression"
    yaml.should.include "git-upload-pack"
    yaml.should.include "backendRequest: 600s"
    # three regex matches share the single backend
    yaml.scan(/RegularExpression/).length.should == 3
  end

  it "renders a terminal https redirect with no backend" do
    yaml = route.(
      name:    "sourcebot-http",
      gateway: "example-com-http",
      domains: ["sg.example.com"],
      prefix:  ["/"],
      redirect: true,
    ).to_yaml

    yaml.should.include "RequestRedirect"
    yaml.should.include "statusCode: 301"
    yaml.should.not.include "backendRefs"
  end

  it "renders a custom redirect with ReplaceFullPath and a 302" do
    yaml = route.(
      name:    "forgejo-login",
      gateway: "example-net-https",
      domains: ["git.example.net"],
      exact:   ["/user/login"],
      redirect: { path: "/user/oauth2/authelia", status: 302 },
    ).to_yaml

    yaml.should.include "ReplaceFullPath"
    yaml.should.include "statusCode: 302"
    yaml.should.include "Exact"
  end

  it "chains multiple middlewares as ExtensionRef filters" do
    yaml = route.(
      name:    "docker-registry",
      gateway: "example-net-https",
      domains: ["registry.example.net"],
      prefix:  ["/"],
      service: { namespace: "docker-registry", name: "docker-registry", port: 80 },
      middleware: ["clear-site-data-cookies", "forwardauth-oauth2-proxy-example"],
    ).to_yaml

    yaml.scan(/ExtensionRef/).length.should == 2
    yaml.should.include "clear-site-data-cookies"
    yaml.should.include "forwardauth-oauth2-proxy-example"
  end

  it "renders a header modifier and a co-located short-form backend" do
    yaml = route.(
      name:      "sogo",
      namespace: "mail",
      gateway:   "example-com-https",
      domains:   ["sogo.example.com"],
      prefix:    ["/"],
      service:   { name: "sogo", port: 80 },
      header_modifier: { remove: ["x-webobjects-remote-user"] },
    ).to_yaml

    yaml.should.include "RequestHeaderModifier"
    yaml.should.include "x-webobjects-remote-user"
  end

  it "supports a websocket header match" do
    yaml = route.(
      name:    "chrome-tool-ws",
      gateway: "example-com-https",
      domains: ["chrome-tool-ws.example.com"],
      prefix:  ["/"],
      service: { namespace: "ai", name: "chrome-tool-ws", port: 8765 },
      headers: { "Upgrade" => "websocket" },
    ).to_yaml

    yaml.should.include "Upgrade"
    yaml.should.include "websocket"
  end

  it "renders multiple hostnames on one route" do
    yaml = route.(
      name:    "git",
      gateway: "example-net-https",
      domains: ["git.example.net", "git.example.com"],
      prefix:  ["/"],
      service: { namespace: "default", name: "forgejo-http", port: 3000 },
    ).to_yaml

    yaml.should.include "git.example.net"
    yaml.should.include "git.example.com"
  end
end
