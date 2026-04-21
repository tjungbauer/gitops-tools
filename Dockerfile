# syntax=docker/dockerfile:1
# 1. Base Image: UBI 9 (Provides GLIBC 2.34, solving the 2.32 requirement)
FROM registry.access.redhat.com/ubi9-minimal:latest

# 2. Tool versions (prebuilt upstream binaries)
#
# Clair / Trivy report CVEs against Go modules *inside* these static binaries — you cannot “patch” them in this
# Dockerfile; refresh by bumping releases when vendors publish rebuilt binaries. Rebuild the image after bumps.
#
# Argo CD CLI — use latest stable from https://github.com/argoproj/argo-cd/releases
ARG ARGO_CD_CLI_VERSION=3.3.7
# Helm 3 line — https://github.com/helm/helm/releases (avoid Helm 4 unless charts are validated for it)
ARG HELM_VERSION=3.20.2
ARG KUSTOMIZE_VERSION=5.8.1
ARG ROLLOUTS_VERSION=1.9.0
ARG POLICYGEN_VERSION=1.17.1
ARG YQ_VERSION=4.52.5
ARG OCP_CLIENT_VERSION=latest

# Labels
LABEL name="custom-argocd-cmp-ubi9" \
      description="ArgoCD CMP sidecar updated to UBI 9 with specific tool versions" \
      policy-gen-version="${POLICYGEN_VERSION}"

# 3. Install system packages from UBI only (no EPEL — yq is installed as a release binary below)
RUN microdnf update -y && \
    microdnf -y install \
    jq \
    tar \
    gzip \
    bc \
    git \
    findutils \
    gettext \
    shadow-utils && \
    microdnf clean all

# 4. Argo CD CMP: home /home/argocd, default uid 999 (vanilla K8s).
#    OpenShift: SCCs usually run the container as an arbitrary UID with GID 0 — use primary
#    group 0 and g=u / g+rwX on writable trees so $HOME and plugins work without uid 999.
RUN useradd --no-log-init -r -u 999 -g 0 -m -d /home/argocd argocd && \
    mkdir -p /home/argocd/cmp-server/config

# 5. Download and install tooling (heredoc: readable sections, one layer; requires BuildKit)
#    Unquoted <<INSTALL so build ARGs (${OCP_CLIENT_VERSION}, …) expand in the shell.
RUN <<INSTALL
set -euo pipefail
mkdir -p /tmp/tools

echo "==> [gitops-tools] Installing CLI tooling (7 components) …"

# --- OpenShift client (oc, kubectl) — OCP_CLIENT_VERSION ---
echo -n "    [1/7] OpenShift client (oc, kubectl) — OCP ${OCP_CLIENT_VERSION} — downloading…"
curl -fsSL \
  "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_CLIENT_VERSION}/openshift-client-linux-amd64-rhel9.tar.gz" \
  -o /tmp/tools/oc.tar.gz
echo " ... extracting…"
tar -xf /tmp/tools/oc.tar.gz -C /usr/local/bin/ oc kubectl

# --- yq (YAML/JSON CLI) ---
echo "    [2/7] yq — ${YQ_VERSION} — downloading…"
curl -fsSL \
  "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" \
  -o /usr/local/bin/yq
chmod +x /usr/local/bin/yq

# --- Argo CD CLI ---
echo "    [3/7] argocd CLI — ${ARGO_CD_CLI_VERSION} — downloading…"
curl -fsSL \
  "https://github.com/argoproj/argo-cd/releases/download/v${ARGO_CD_CLI_VERSION}/argocd-linux-amd64" \
  -o /usr/local/bin/argocd
chmod +x /usr/local/bin/argocd

# --- Argo Rollouts kubectl plugin ---
echo "    [4/7] kubectl-argo-rollouts — ${ROLLOUTS_VERSION} — downloading…"
curl -fsSL \
  "https://github.com/argoproj/argo-rollouts/releases/download/v${ROLLOUTS_VERSION}/kubectl-argo-rollouts-linux-amd64" \
  -o /usr/local/bin/kubectl-argo-rollouts
chmod +x /usr/local/bin/kubectl-argo-rollouts

# --- Kustomize ---
echo -n "    [5/7] kustomize — ${KUSTOMIZE_VERSION} — downloading…"
curl -fsSL \
  "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" \
  -o /tmp/tools/kustomize.tar.gz
echo " ... extracting…"
tar -xf /tmp/tools/kustomize.tar.gz -C /usr/local/bin/

# --- Helm 3 ---
echo -n "    [6/7] helm — ${HELM_VERSION} — downloading…"
curl -fsSL \
  "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
  -o /tmp/tools/helm.tar.gz
echo " ... extracting…"
tar -xf /tmp/tools/helm.tar.gz -C /tmp/tools
mv /tmp/tools/linux-amd64/helm /usr/local/bin/helm

# --- OCM policy generator (Kustomize plugin) ---
echo "    [7/7] PolicyGenerator — ${POLICYGEN_VERSION} — downloading…"
POLICY_PLUGIN_ROOT=/etc/kustomize/plugin/policy.open-cluster-management.io/v1/policygenerator
mkdir -p "${POLICY_PLUGIN_ROOT}"
curl -fsSL \
  "https://github.com/open-cluster-management-io/policy-generator-plugin/releases/download/v${POLICYGEN_VERSION}/linux-amd64-PolicyGenerator" \
  -o "${POLICY_PLUGIN_ROOT}/PolicyGenerator"
chmod +x "${POLICY_PLUGIN_ROOT}/PolicyGenerator"

echo "==> [gitops-tools] CLI tooling install finished."
echo "    cleaning /tmp/tools …"
rm -rf /tmp/tools
INSTALL

# 6. OpenShift-friendly group perms (GID 0 can read/write like the owner on these paths)
RUN chgrp -R 0 /home/argocd /etc/kustomize && \
    chmod -R g=u /home/argocd /etc/kustomize

USER 999
WORKDIR /home/argocd
CMD ["/bin/bash"]