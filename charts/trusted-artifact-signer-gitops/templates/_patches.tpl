{{/*
Create the list of patches to apply.
*/}}
{{- define "trusted-artifact-signer-gitops.patches" -}}
{{- $patches := concat ((include "trusted-artifact-signer-gitops.ingressPatches" .) | fromYamlArray) (concat ((include "trusted-artifact-signer-gitops.miscPatches" .) | fromYamlArray) (concat ((include "trusted-artifact-signer-gitops.cliDownloads" .) | fromYamlArray) ((include "trusted-artifact-signer-gitops.fulcioConfig" .) | fromYamlArray))) -}}
{{- $patches | toYaml -}}
{{- end }}


{{/*
Ingress Patches.
*/}}
{{- define "trusted-artifact-signer-gitops.ingressPatches" -}}
- patch: |-
    - op: replace
      path: /spec/rules/0/host
      value: fulcio.{{ $.Values.appsSubdomain }}
  target:
    kind: Ingress
    name: fulcio-server-http
- patch: |-
    - op: replace
      path: /spec/rules/0/host
      value: rekor.{{ $.Values.appsSubdomain }}
  target:
    kind: Ingress
    name: rekor-server
- patch: |-
    - op: replace
      path: /spec/rules/0/host
      value: tuf.{{ $.Values.appsSubdomain }}
  target:
    kind: Ingress
    name: tuf-server
- patch: |-
    - op: add
      path: /spec/host
      value: tas-clients-trusted-artifact-signer-clientserver.{{ $.Values.appsSubdomain }}
  target:
    kind: Route
    name: tas-clients
{{- end }}

{{/*
CLI Download Patches.
*/}}
{{- define "trusted-artifact-signer-gitops.cliDownloads" -}}
- patch: |-
    - op: replace
      path: /spec/links/0/href
      value: https://tas-clients-trusted-artifact-signer-clientserver.{{ $.Values.appsSubdomain }}/clients/linux/cosign.gz
    - op: replace
      path: /spec/links/1/href
      value: https://tas-clients-trusted-artifact-signer-clientserver.{{ $.Values.appsSubdomain }}/clients/windows/cosign.gz
    - op: replace
      path: /spec/links/2/href
      value: https://tas-clients-trusted-artifact-signer-clientserver.{{ $.Values.appsSubdomain }}/clients/darwin/cosign.gz
  target:
    kind: ConsoleCLIDownload
    name: cosign
- patch: |-
    - op: replace
      path: /spec/links/0/href
      value: https://tas-clients-trusted-artifact-signer-clientserver.{{ $.Values.appsSubdomain }}/clients/linux/gitsign.gz
    - op: replace
      path: /spec/links/1/href
      value: https://tas-clients-trusted-artifact-signer-clientserver.{{ $.Values.appsSubdomain }}/clients/darwin/gitsign.gz
    - op: replace
      path: /spec/links/2/href
      value: https://tas-clients-trusted-artifact-signer-clientserver.{{ $.Values.appsSubdomain }}/clients/windows/gitsign.gz
  target:
    kind: ConsoleCLIDownload
    name: gitsign
- patch: |-
    - op: replace
      path: /spec/links/0/href
      value: https://tas-clients-trusted-artifact-signer-clientserver.{{ $.Values.appsSubdomain }}/clients/linux/rekor-cli.gz
    - op: replace
      path: /spec/links/1/href
      value: https://tas-clients-trusted-artifact-signer-clientserver.{{ $.Values.appsSubdomain }}/clients/darwin/rekor-cli.gz
    - op: replace
      path: /spec/links/2/href
      value: https://tas-clients-trusted-artifact-signer-clientserver.{{ $.Values.appsSubdomain }}/clients/windows/rekor-cli.gz
  target:
    kind: ConsoleCLIDownload
    name: rekor-cli
{{- end }}

{{/*
Fulcio Config.
*/}}
{{- define "trusted-artifact-signer-gitops.fulcioConfig" -}}
- patch: |-
    - op: replace
      path: /data/config.json
      value: |
        {
            "OIDCIssuers": {{- ((include "trusted-artifact-signer-gitops.oidcIssuers" .) | fromJson) | toPrettyJson | nindent 14 -}}
        }
  target:
    kind: ConfigMap
    name: fulcio-server-config
{{- end }}

{{/*
OIDC Issuers.
*/}}
{{- define "trusted-artifact-signer-gitops.oidcIssuers" -}}
{{- $oidcIssuers := merge ((include "trusted-artifact-signer-gitops.oidcEmailConfig" .) | fromJson) ((include "trusted-artifact-signer-gitops.oidcSpiffeConfig" .) | fromJson) -}}
{{- $oidcIssuers | toJson -}}
{{- end }}

{{/*
Keycloak OIDC Issuer.
*/}}
{{- define "trusted-artifact-signer-gitops.oidcEmailConfig" -}}
{
    "https://keycloak-keycloak-system.{{ $.Values.appsSubdomain }}/auth/realms/sigstore": {
       "ClientID": "sigstore",
        "IssuerURL": "https://keycloak-keycloak-system.{{ $.Values.appsSubdomain }}/auth/realms/sigstore",
        "Type": "email"
  }
}
{{- end }}

{{/*
SPIFFE OIDC Issuers.
*/}}
{{- define "trusted-artifact-signer-gitops.oidcSpiffeConfig" -}}
{
  {{- if $.Values.rhtas.spiffe.enabled -}}
    "https://oidc-discovery.{{ $.Values.appsSubdomain }}": {
       "ClientID": "sigstore",
        "IssuerURL": "https://oidc-discovery.{{ $.Values.appsSubdomain }}",
        "Type": "spiffe",
        "SPIFFETrustDomain": "{{ $.Values.appsSubdomain }}"
  }
{{- end -}}
}
{{- end }}

{{/*
Misc Patches.
*/}}
{{- define "trusted-artifact-signer-gitops.miscPatches" -}}
{{- if $.Values.rhtas.pull_secret -}}
- patch: |-
    - op: replace
      path: /data/pull-secret.json
      value: {{ $.Values.rhtas.pull_secret | b64enc }}
  target:
    kind: Secret
    name: pull-secret
{{- else -}}
- patch: |-
    - op: add
      path: /spec/suspend
      value: true
    - op: remove
      path: /spec/jobTemplate/spec/template/spec/containers/0/env
    - op: replace
      path: /spec/jobTemplate/spec/template/spec/containers/0/command
      value: ["/bin/bash", "-c", "echo 'Pull Secret Not Provided. Segment Backup Job Disabled'"]
  target:
    kind: CronJob
    name: segment-backup-job
- patch: |-
    - op: remove
      path: /spec/template/spec/containers/0/env
    - op: replace
      path: /spec/template/spec/containers/0/command
      value: ["/bin/bash", "-c", "echo 'Pull Secret Not Provided. Segment Backup Job Disabled'"]
  target:
    kind: Job
    name: segment-backup-job
{{- end -}}
{{- end }}