{{/*
Expand the name of the chart.
*/}}
{{- define "yogo-ai-controller.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "yogo-ai-controller.fullname" -}}
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
{{- define "yogo-ai-controller.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "yogo-ai-controller.labels" -}}
helm.sh/chart: {{ include "yogo-ai-controller.chart" . }}
{{ include "yogo-ai-controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "yogo-ai-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "yogo-ai-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "yogo-ai-controller.serviceAccountName" -}}
{{- printf "%s-manager" (include "yogo-ai-controller.fullname" .) }}
{{- end }}

{{/*
Create the name of the cluster role to use
*/}}
{{- define "yogo-ai-controller.clusterRoleName" -}}
{{- printf "%s-manager-role" (include "yogo-ai-controller.fullname" .) }}
{{- end }}

{{/*
Create the name of the cluster role binding to use
*/}}
{{- define "yogo-ai-controller.clusterRoleBindingName" -}}
{{- printf "%s-manager-rolebinding" (include "yogo-ai-controller.fullname" .) }}
{{- end }}

{{/*
Merge global annotations with resource-specific annotations.
Resource-specific annotations take precedence over global annotations.
Usage: include "yogo-ai-controller.annotations" (dict "global" .Values.annotations "local" .Values.ingress.annotations)
*/}}
{{- define "yogo-ai-controller.annotations" -}}
{{- $global := .global | default dict -}}
{{- $local := .local | default dict -}}
{{- $merged := merge $local $global -}}
{{- if $merged -}}
{{- toYaml $merged -}}
{{- end -}}
{{- end -}}