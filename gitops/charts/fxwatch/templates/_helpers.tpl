{{- define "fxwatch.labels" -}}
app.kubernetes.io/part-of: fxwatch
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{- define "fxwatch.image" -}}
{{- $ctx := index . 0 -}}
{{- $repo := index . 1 -}}
{{ required "image.registry is required" $ctx.Values.image.registry }}/{{ $repo }}:{{ required "image.tag is required" $ctx.Values.image.tag }}
{{- end }}

{{/* Shared hardening for our Node containers (image user "node" = uid 1000) */}}
{{- define "fxwatch.podSecurity" -}}
runAsNonRoot: true
runAsUser: 1000
runAsGroup: 1000
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{- define "fxwatch.containerSecurity" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end }}