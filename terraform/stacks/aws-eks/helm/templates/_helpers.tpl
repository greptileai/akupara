{{/*
Purpose:
- Shared helper templates (names, chart label, common labels).
- Keeps resource naming/labeling consistent across manifests in this chart.
*/}}

{{- define "greptileEks.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "greptileEks.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end }}

{{- define "greptileEks.labels" -}}
app.kubernetes.io/name: {{ include "greptileEks.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "greptileEks.chart" . }}
{{- end }}
