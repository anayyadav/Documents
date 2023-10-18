{{/*
Expand the name of the chart.
*/}}
{{- define "base-chart.name" -}}
    {{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "base-chart.fullname" -}}
    {{- if .Values.serviceName }}
        {{- .Values.serviceName | trunc 63 | trimSuffix "-" }}
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
{{- define "base-chart.chart" -}}
    {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create the name of the service account to use
*/}}
{{- define "base-chart.serviceAccountName" -}}
    {{- if .Values.serviceAccount.create }}
        {{- default (include "base-chart.fullname" .) .Values.serviceAccount.name }}
    {{- else }}
        {{- default "default" .Values.serviceAccount.name }}
    {{- end }}
{{- end }}
