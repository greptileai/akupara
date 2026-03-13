{{- define "greptile.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "greptile.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "greptile.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "greptile.labels" -}}
helm.sh/chart: {{ include "greptile.chart" . }}
app.kubernetes.io/name: {{ include "greptile.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "greptile.selectorLabels" -}}
app.kubernetes.io/name: {{ include "greptile.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "greptile.serviceAccountName" -}}
{{- include "greptile.fullname" . -}}
{{- end -}}

{{- define "greptile.secretName" -}}
{{- if .Values.secrets.name -}}
{{- .Values.secrets.name -}}
{{- else -}}
{{- printf "%s-secrets" (include "greptile.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "greptile.llmproxyConfigName" -}}
{{- printf "%s-llmproxy-config" (include "greptile.fullname" .) -}}
{{- end -}}

{{- define "greptile.sharedPvcName" -}}
{{- printf "%s-shared-workdir" (include "greptile.fullname" .) -}}
{{- end -}}

{{- define "greptile.pgbouncerName" -}}
{{- printf "%s-pgbouncer" (include "greptile.fullname" .) -}}
{{- end -}}

{{- define "greptile.componentName" -}}
{{- printf "%s-%s" (include "greptile.fullname" .root) .name -}}
{{- end -}}

{{- define "greptile.componentImage" -}}
{{- $root := .root -}}
{{- $comp := .component -}}
{{- if contains "/" $comp.image.repository -}}
{{- printf "%s:%s" $comp.image.repository (default $root.Values.global.tag $comp.image.tag) -}}
{{- else -}}
{{- printf "%s/%s:%s" $root.Values.global.registry $comp.image.repository (default $root.Values.global.tag $comp.image.tag) -}}
{{- end -}}
{{- end -}}

{{- define "greptile.image" -}}
{{- $root := .root -}}
{{- $repository := .repository -}}
{{- $tag := .tag -}}
{{- if contains "/" $repository -}}
{{- printf "%s:%s" $repository (default $root.Values.global.tag $tag) -}}
{{- else -}}
{{- printf "%s/%s:%s" $root.Values.global.registry $repository (default $root.Values.global.tag $tag) -}}
{{- end -}}
{{- end -}}

{{- define "greptile.databaseHost" -}}
{{- if .Values.postgres.enabled -}}
{{ printf "%s-postgresql" (include "greptile.fullname" .) }}
{{- else -}}
{{ .Values.externalDatabase.host }}
{{- end -}}
{{- end -}}

{{- define "greptile.databasePort" -}}
{{- if .Values.postgres.enabled -}}
{{ .Values.postgres.primary.service.port | toString }}
{{- else -}}
{{ .Values.externalDatabase.port | toString }}
{{- end -}}
{{- end -}}

{{- define "greptile.databaseUser" -}}
{{- if .Values.postgres.enabled -}}
{{ .Values.postgres.auth.username }}
{{- else -}}
{{ .Values.externalDatabase.user }}
{{- end -}}
{{- end -}}

{{- define "greptile.databasePassword" -}}
{{- if .Values.postgres.enabled -}}
{{ .Values.postgres.auth.postgresPassword }}
{{- else -}}
{{ .Values.externalDatabase.password }}
{{- end -}}
{{- end -}}

{{- define "greptile.databaseName" -}}
{{- if .Values.postgres.enabled -}}
{{ .Values.postgres.auth.database }}
{{- else -}}
{{ .Values.externalDatabase.database }}
{{- end -}}
{{- end -}}

{{- define "greptile.vectorDatabaseName" -}}
{{- if .Values.postgres.enabled -}}
vector
{{- else -}}
{{ .Values.externalDatabase.vectorDatabase }}
{{- end -}}
{{- end -}}

{{- define "greptile.databaseUrl" -}}
{{- printf "postgresql://%s:%s@%s:%s/%s" (include "greptile.databaseUser" .) (include "greptile.databasePassword" .) (include "greptile.databaseHost" .) (include "greptile.databasePort" .) (include "greptile.databaseName" .) -}}
{{- end -}}

{{- define "greptile.databasePooledHost" -}}
{{- if .Values.pgbouncer.enabled -}}
{{ include "greptile.pgbouncerName" . }}
{{- else -}}
{{ include "greptile.databaseHost" . }}
{{- end -}}
{{- end -}}

{{- define "greptile.databasePooledPort" -}}
{{- if .Values.pgbouncer.enabled -}}
{{ .Values.pgbouncer.service.port | toString }}
{{- else -}}
{{ include "greptile.databasePort" . }}
{{- end -}}
{{- end -}}

{{- define "greptile.databasePooledUrl" -}}
{{- printf "postgresql://%s:%s@%s:%s/%s" (include "greptile.databaseUser" .) (include "greptile.databasePassword" .) (include "greptile.databasePooledHost" .) (include "greptile.databasePooledPort" .) (include "greptile.databaseName" .) -}}
{{- end -}}

{{- define "greptile.vectorDatabaseUrl" -}}
{{- printf "postgresql://%s:%s@%s:%s/%s" (include "greptile.databaseUser" .) (include "greptile.databasePassword" .) (include "greptile.databaseHost" .) (include "greptile.databasePort" .) (include "greptile.vectorDatabaseName" .) -}}
{{- end -}}
