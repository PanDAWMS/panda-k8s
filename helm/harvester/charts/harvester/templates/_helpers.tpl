{{/*
Expand the name of the chart.
*/}}
{{- define "harvester.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "harvester.fullname" -}}
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
{{- define "harvester.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "harvester.labels" -}}
helm.sh/chart: {{ include "harvester.chart" . }}
{{ include "harvester.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "harvester.labels-condor-logs" -}}
helm.sh/chart: {{ include "harvester.chart" . }}
{{ include "harvester.selectorLabels-condor-logs" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "harvester.labels-wdirs" -}}
helm.sh/chart: {{ include "harvester.chart" . }}
{{ include "harvester.selectorLabels-wdirs" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "harvester.selectorLabels" -}}
app.kubernetes.io/name: {{ include "harvester.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "harvester.selectorLabels-condor-logs" -}}
app.kubernetes.io/name: {{ include "harvester.name" . }}-condor-logs
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "harvester.selectorLabels-wdirs" -}}
app.kubernetes.io/name: {{ include "harvester.name" . }}-wdirs
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "harvester.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "harvester.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
