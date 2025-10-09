{{/*
Expand the name of the chart.
*/}}
{{- define "greptile.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "greptile.fullname" -}}
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
{{- define "greptile.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "greptile.labels" -}}
helm.sh/chart: {{ include "greptile.chart" . }}
{{ include "greptile.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "greptile.selectorLabels" -}}
app.kubernetes.io/name: {{ include "greptile.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "greptile.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "greptile.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database URL template
*/}}
{{- define "greptile.databaseUrl" -}}
{{- if .Values.postgresql.enabled }}
{{- if .Values.pgbouncer.enabled }}
{{- printf "postgresql://%s:%s@%s:%s/%s?pgbouncer=true" .Values.postgresql.auth.postgresPassword .Values.postgresql.auth.postgresPassword (printf "%s-pgbouncer" (include "greptile.fullname" .)) (.Values.pgbouncer.service.port | toString) .Values.postgresql.auth.database }}
{{- else }}
{{- printf "postgresql://%s:%s@%s:%s/%s" .Values.postgresql.auth.postgresPassword .Values.postgresql.auth.postgresPassword (printf "%s-postgresql" (include "greptile.fullname" .)) (.Values.postgresql.primary.service.port | toString) .Values.postgresql.auth.database }}
{{- end }}
{{- else }}
{{- .Values.database.url }}
{{- end }}
{{- end }}

{{/*
Vector Database URL template
*/}}
{{- define "greptile.vectorDatabaseUrl" -}}
{{- if .Values.postgresql.enabled }}
{{- if .Values.pgbouncer.enabled }}
{{- printf "postgresql://%s:%s@%s:%s/vector?pgbouncer=true" .Values.postgresql.auth.postgresPassword .Values.postgresql.auth.postgresPassword (printf "%s-pgbouncer" (include "greptile.fullname" .)) (.Values.pgbouncer.service.port | toString) }}
{{- else }}
{{- printf "postgresql://%s:%s@%s:%s/vector" .Values.postgresql.auth.postgresPassword .Values.postgresql.auth.postgresPassword (printf "%s-postgresql" (include "greptile.fullname" .)) (.Values.postgresql.primary.service.port | toString) }}
{{- end }}
{{- else }}
{{- .Values.vectordb.url }}
{{- end }}
{{- end }}

{{/*
Redis URL template
*/}}
{{- define "greptile.redisUrl" -}}
{{- if .Values.redis.enabled }}
{{- printf "%s-redis-master:%s" (include "greptile.fullname" .) (.Values.redis.master.service.port | toString) }}
{{- else }}
{{- .Values.redis.host }}
{{- end }}
{{- end }}

{{/*
Direct Database URL template (always bypasses pgbouncer for migrations)
*/}}
{{- define "greptile.directDatabaseUrl" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "postgresql://%s:%s@%s:%s/%s" .Values.postgresql.auth.postgresPassword .Values.postgresql.auth.postgresPassword (printf "%s-postgresql" (include "greptile.fullname" .)) (.Values.postgresql.primary.service.port | toString) .Values.postgresql.auth.database }}
{{- else }}
{{- .Values.database.url }}
{{- end }}
{{- end }}

{{/*
Image name template
*/}}
{{- define "greptile.image" -}}
{{- printf "%s/%s:%s" .Values.global.ecr.registry .repository .tag }}
{{- end }} 