{{- define "ci-project.name" -}}
{{- required "name is required" .Values.name -}}
{{- end -}}

{{- define "ci-project.ciNamespace" -}}
ci-{{ include "ci-project.name" . }}
{{- end -}}

{{- define "ci-project.buildNamespace" -}}
build-{{ include "ci-project.name" . }}
{{- end -}}

{{- define "ci-project.labels" -}}
app.kubernetes.io/part-of: ci
app.kubernetes.io/managed-by: {{ .Release.Service }}
ci.home.arpa/project: {{ include "ci-project.name" . }}
{{- end -}}

{{/* egress to the git provider, for clones from pipeline and build pods */}}
{{- define "ci-project.gitEgress" -}}
{{- if eq .Values.repository.provider "forgejo" }}
- toEndpoints:
    - matchLabels:
        io.kubernetes.pod.namespace: forgejo
        app: forgejo
  toPorts:
    - ports:
        - port: "3000"
          protocol: TCP
{{- with .Values.repository.forgejoPublicHost }}
# public Forgejo URL through the shared gateway (private-repo clones)
- toEntities:
    - ingress
  toPorts:
    - ports:
        - port: "443"
          protocol: TCP
- toFQDNs:
    - matchName: {{ . | quote }}
  toPorts:
    - ports:
        - port: "443"
          protocol: TCP
{{- end }}
{{- else if eq .Values.repository.provider "github" }}
- toFQDNs:
    - matchName: github.com
  toPorts:
    - ports:
        - port: "443"
          protocol: TCP
{{- else }}
{{- fail "repository.provider must be forgejo or github" }}
{{- end }}
{{- with .Values.egressFQDNs }}
- toFQDNs:
  {{- range . }}
    {{- if contains "*" . }}
    - matchPattern: {{ . | quote }}
    {{- else }}
    - matchName: {{ . | quote }}
    {{- end }}
  {{- end }}
  toPorts:
    - ports:
        - port: "443"
          protocol: TCP
{{- end }}
{{- end -}}

{{/*
Egress to Harbor through the shared gateway. The gateway's Envoy also checks
the client's egress against the backend it proxies to, so harbor-core itself
must be allowed too.
*/}}
{{- define "ci-project.registryEgress" -}}
- toEntities:
    - ingress
  toPorts:
    - ports:
        - port: "443"
          protocol: TCP
- toFQDNs:
    - matchName: {{ .Values.build.registryHost | quote }}
  toPorts:
    - ports:
        - port: "443"
          protocol: TCP
- toEndpoints:
    - matchLabels:
        io.kubernetes.pod.namespace: harbor
        app: harbor
        component: core
  toPorts:
    - ports:
        - port: "8080"
          protocol: TCP
{{- end }}
