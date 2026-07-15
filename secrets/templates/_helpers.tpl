{{/*
Expand the name of the chart.
*/}}
{{- define "secrets.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "secrets.fullname" -}}
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
{{- define "secrets.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "secrets.labels" -}}
helm.sh/chart: {{ include "secrets.chart" . }}
{{ include "secrets.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "secrets.selectorLabels" -}}
app.kubernetes.io/name: {{ include "secrets.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "secrets.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "secrets.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Add affix to refer the instance names
*/}}
{{- define "add_affix" }}
{{- $affix := index . 0 }}
{{- $body := index . 1 }}
{{- if hasPrefix "-" $affix }}
{{- printf "%s%s" $body $affix }}
{{- else }}
{{- printf "%s%s" $affix $body }}
{{- end }}
{{- end }}

{{/*
Add affix to instance reference names
*/}}
{{- define "iam_ref" }}
{{- include "add_affix" (list .Values.affix "iam") }}
{{- end }}

{{- define "msgsvc_ref" }}
{{- include "add_affix" (list .Values.affix "msgsvc") }}
{{- end }}

{{- define "panda_ref" }}
{{- include "add_affix" (list .Values.affix "panda") }}
{{- end }}

{{- define "idds_ref" }}
{{- include "add_affix" (list .Values.affix "idds") }}
{{- end }}

{{- define "harvester_ref" }}
{{- include "add_affix" (list .Values.affix "harvester") }}
{{- end }}

{{- define "bigmon_ref" }}
{{- include "add_affix" (list .Values.affix "bigmon") }}
{{- end }}

{{- define "ui_ref" }}
{{- include "add_affix" (list .Values.affix "ui") }}
{{- end }}


{{/*
Set Proxies
*/}}
{{- define "set_proxy" }}
{{- if .Values.proxy.httpProxy }}
http_proxy: "{{ .Values.proxy.httpProxy }}"
{{- if .Values.proxy.noProxy }}
no_proxy: "{{ .Values.proxy.noProxy }}"
{{- else }}
no_proxy: "localhost,{{ include "panda_ref" . }}-server,{{ include "idds_ref" . }}-rest"
{{- end }}
{{- if .Values.proxy.httpsProxy }}
https_proxy: "{{ .Values.proxy.httpProxy }}"
{{- end }}
{{- else if .Values.proxy.httpsProxy }}
https_proxy: "{{ .Values.proxy.httpsProxy }}"
{{- if .Values.proxy.noProxy }}
no_proxy: "{{ .Values.proxy.noProxy }}"
{{- else }}
no_proxy: "localhost,{{ include "panda_ref" . }}-server,{{ include "idds_ref" . }}-rest"
{{- end }}
{{- end }}
{{- end }}
