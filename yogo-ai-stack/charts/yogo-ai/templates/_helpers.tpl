{{/*
Expand the name of the chart.
*/}}
{{- define "yogo-ai.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "yogo-ai.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "yogo-ai.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "yogo-ai.labels" -}}
helm.sh/chart: {{ include "yogo-ai.chart" . }}
{{ include "yogo-ai.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "yogo-ai.selectorLabels" -}}
app.kubernetes.io/name: {{ include "yogo-ai.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "yogo-ai.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "yogo-ai.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Merge global annotations with resource-specific annotations.
Resource-specific annotations take precedence over global annotations.
Usage: include "yogo-ai.annotations" (dict "global" .Values.annotations "local" .Values.ingress.annotations)
*/}}
{{- define "yogo-ai.annotations" -}}
{{- $global := .global | default dict -}}
{{- $local := .local | default dict -}}
{{- $merged := merge (deepCopy $local) $global -}}
{{- if $merged -}}
{{- toYaml $merged -}}
{{- end -}}
{{- end -}}

{{/*
Build DOT_AI_PLUGINS_CONFIG JSON from enabled plugins.
Supports two modes:
  - Deployed: image + port → auto-generates endpoint URL
  - External: endpoint → uses provided URL
*/}}
{{/*
Dex external host — derived from the main ingress/gateway host.
Prepends "dex." to the main host (e.g., dot-ai.example.com → dex.dot-ai.example.com).
*/}}
{{- define "yogo-ai.dexExternalHost" -}}
{{- $host := "" -}}
{{- if .Values.ingress.enabled -}}
  {{- $host = .Values.ingress.host -}}
{{- else if .Values.gateway.listeners.https.hostname -}}
  {{- $host = .Values.gateway.listeners.https.hostname -}}
{{- else if .Values.gateway.listeners.http.hostname -}}
  {{- $host = .Values.gateway.listeners.http.hostname -}}
{{- end -}}
{{- if $host -}}
dex.{{ $host }}
{{- end -}}
{{- end -}}

{{/*
Dex external URL — full URL including scheme and optional port.
Used as the Dex issuer URL and for browser redirects.
*/}}
{{- define "yogo-ai.dexExternalUrl" -}}
{{- if .Values.dex.externalUrl -}}
{{ .Values.dex.externalUrl }}
{{- else -}}
{{- $host := include "yogo-ai.dexExternalHost" . -}}
{{- if $host -}}
{{- if or .Values.ingress.tls.enabled .Values.gateway.listeners.https.hostname -}}
https://{{ $host }}
{{- else -}}
http://{{ $host }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
dot-ai external URL — full URL of the main MCP server.
Used for OAuth callback redirect URI.
*/}}
{{- define "yogo-ai.externalUrl" -}}
{{- if .Values.externalUrl -}}
{{ .Values.externalUrl }}
{{- else if .Values.ingress.enabled -}}
  {{- if .Values.ingress.tls.enabled -}}
https://{{ .Values.ingress.host }}
  {{- else -}}
http://{{ .Values.ingress.host }}
  {{- end -}}
{{- else if .Values.gateway.listeners.https.hostname -}}
https://{{ .Values.gateway.listeners.https.hostname }}
{{- else if .Values.gateway.listeners.http.hostname -}}
http://{{ .Values.gateway.listeners.http.hostname }}
{{- end -}}
{{- end -}}

{{/*
Dex in-cluster token endpoint — for server-to-server token exchange.
The MCP server pod uses this URL (not the external one) to talk to Dex.
*/}}
{{- define "yogo-ai.dexTokenEndpoint" -}}
http://{{ .Release.Name }}-dex.{{ .Release.Namespace }}.svc.cluster.local:5556/token
{{- end -}}

{{/*
Dex in-cluster gRPC endpoint — for user management via Dex gRPC API (PRD #380 Task 2.5).
*/}}
{{- define "yogo-ai.dexGrpcEndpoint" -}}
{{ .Release.Name }}-dex.{{ .Release.Namespace }}.svc.cluster.local:5557
{{- end -}}

{{/*
MCP Servers Configuration (PRD #358, PRD #414)
Generates JSON array of MCP server configs for discovery by dot-ai.
Each entry includes: name, endpoint, attachTo, and optional auth with env var names.
Auth credentials are injected as env vars from K8s Secrets (not stored in ConfigMap).
*/}}
{{- define "yogo-ai.mcpServersConfig" -}}
{{- $servers := list -}}
{{- range $name, $config := .Values.mcpServers -}}
{{- if $config.enabled -}}
{{- if not $config.endpoint -}}
{{- fail (printf "mcpServers.%s is enabled but has no endpoint configured" $name) -}}
{{- end -}}
{{- $server := dict "name" $name "endpoint" $config.endpoint "attachTo" $config.attachTo -}}
{{- $upperName := $name | upper | replace "-" "_" -}}
{{- if $config.auth -}}
{{- $auth := dict -}}
{{- if $config.auth.token -}}
{{- $_ := set $auth "tokenEnvVar" (printf "MCP_AUTH_%s" $upperName) -}}
{{- end -}}
{{- if $config.auth.headers -}}
{{- $_ := set $auth "headersEnvVar" (printf "MCP_HEADERS_%s" $upperName) -}}
{{- end -}}
{{- if $config.auth.oauth -}}
{{- $oauth := dict "clientId" $config.auth.oauth.clientId "clientSecretEnvVar" (printf "MCP_OAUTH_SECRET_%s" $upperName) -}}
{{- if $config.auth.oauth.scope -}}
{{- $_ := set $oauth "scope" $config.auth.oauth.scope -}}
{{- end -}}
{{- $_ := set $auth "oauth" $oauth -}}
{{- end -}}
{{- if $auth -}}
{{- $server = merge $server (dict "auth" $auth) -}}
{{- end -}}
{{- end -}}
{{- $servers = append $servers $server -}}
{{- end -}}
{{- end -}}
{{- $servers | toJson -}}
{{- end -}}

{{- define "yogo-ai.pluginsConfig" -}}
{{- $plugins := list -}}
{{- range $name, $config := .Values.plugins -}}
{{- if $config.enabled -}}
{{- $endpoint := "" -}}
{{- if $config.endpoint -}}
{{- $endpoint = $config.endpoint -}}
{{- else if $config.image -}}
{{- $port := required (printf "plugins.%s.port is required when image is set" $name) $config.port -}}
{{- $endpoint = printf "http://%s-%s:%d" $.Release.Name $name (int $port) -}}
{{- else -}}
{{- fail (printf "plugins.%s is enabled but has neither endpoint nor image configured" $name) -}}
{{- end -}}
{{- if $endpoint -}}
{{- $plugins = append $plugins (dict "name" $name "url" $endpoint) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $plugins | toJson -}}
{{- end -}}