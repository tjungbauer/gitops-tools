# 1. Base Image: UBI 9 (Provides GLIBC 2.34, solving the 2.32 requirement)
FROM registry.access.redhat.com/ubi9-minimal:latest

# 2. Updated Build Arguments
ARG ARGO_CD_CLI_VERSION=3.3.2
ARG HELM_VERSION=3.19.4
ARG KUSTOMIZE_VERSION=5.8.1
ARG ROLLOUTS_VERSION=1.8.4
ARG POLICYGEN_VERSION=1.17.1

# Labels
LABEL name="custom-argocd-cmp-ubi9" \
      description="ArgoCD CMP sidecar updated to UBI 9 with specific tool versions" \
      policy-gen-version="${POLICYGEN_VERSION}"

# 3. Install System Dependencies (EPEL first: provides siege)
RUN curl -fsSL https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm -o /tmp/epel.rpm && \
    rpm -ivh /tmp/epel.rpm && \
    microdnf -y install \
    jq \
    yq \
    tar \
    gzip \
    bc \
    git \
    findutils \
    gettext \
    siege \
    shadow-utils && \
    rm -f /tmp/epel.rpm && \
    microdnf clean all

# 4. Argo CD CMP: home /home/argocd, default uid 999 (vanilla K8s).
#    OpenShift: SCCs usually run the container as an arbitrary UID with GID 0 — use primary
#    group 0 and g=u / g+rwX on writable trees so $HOME and plugins work without uid 999.
RUN useradd --no-log-init -r -u 999 -g 0 -m -d /home/argocd argocd && \
    mkdir -p /home/argocd/cmp-server/config

# 5. Download and Install Tooling
RUN mkdir -p /tmp/tools && \
    # OpenShift & Kubectl (Stable)
    curl -fsSL https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux-amd64-rhel9.tar.gz -o /tmp/tools/oc.tar.gz && \
    tar -xvf /tmp/tools/oc.tar.gz -C /usr/local/bin/ oc kubectl && \
    # ArgoCD CLI
    curl -fsSL https://github.com/argoproj/argo-cd/releases/download/v${ARGO_CD_CLI_VERSION}/argocd-linux-amd64 -o /usr/local/bin/argocd && \
    chmod +x /usr/local/bin/argocd && \
    # Argo Rollouts (v1.8.4)
    curl -fsSL https://github.com/argoproj/argo-rollouts/releases/download/v${ROLLOUTS_VERSION}/kubectl-argo-rollouts-linux-amd64 -o /usr/local/bin/kubectl-argo-rollouts && \
    chmod +x /usr/local/bin/kubectl-argo-rollouts && \
    # Kustomize (v5.8.1)
    curl -fsSL https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz -o /tmp/tools/kustomize.tar.gz && \
    tar -xvf /tmp/tools/kustomize.tar.gz -C /usr/local/bin/ && \
    # Helm (v3.19.4)
    curl -fsSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz -o /tmp/tools/helm.tar.gz && \
    tar -xvf /tmp/tools/helm.tar.gz -C /tmp/tools && \
    mv /tmp/tools/linux-amd64/helm /usr/local/bin/helm && \
    # Policy Generator Plugin (v1.17.1)
    mkdir -p /etc/kustomize/plugin/policy.open-cluster-management.io/v1/policygenerator && \
    curl -fsSL https://github.com/open-cluster-management-io/policy-generator-plugin/releases/download/v${POLICYGEN_VERSION}/linux-amd64-PolicyGenerator -o /etc/kustomize/plugin/policy.open-cluster-management.io/v1/policygenerator/PolicyGenerator && \
    chmod +x /etc/kustomize/plugin/policy.open-cluster-management.io/v1/policygenerator/PolicyGenerator && \
    # Leftovers
    # # Download ksuid
    # curl -fsSL https://github.com/segmentio/ksuid/releases/download/v1.0.4/ksuid_1.0.4_linux_amd64.tar.gz | tar -C /usr/local/bin/ -xz ksuid_1.0.4_linux_amd64/ksuid --strip-components=1 && \
    # # Download a common Go-based envsubst (often renamed to envsub)
    # curl -fsSL https://github.com/a8m/envsubst/releases/download/v1.4.2/envsubst-Linux-x86_64 -o /usr/local/bin/envsub && \
    # chmod +x /usr/local/bin/ksuid /usr/local/bin/envsub && \
    # Cleanup
    rm -rf /tmp/tools


# 6. Copy Local Assets (Ensure these files are present in your build directory)
#COPY envsub /usr/local/bin/envsub
#COPY ksuid /usr/local/bin/ksuid
COPY siege.conf /.siege/siege.conf

# 7. OpenShift-friendly group perms (GID 0 can read/write like the owner on these paths)
#RUN chmod +x /usr/local/bin/envsub /usr/local/bin/ksuid && \
RUN mkdir -p /.siege && \
    chgrp -R 0 /home/argocd /etc/kustomize /.siege && \
    chmod -R g=u /home/argocd /etc/kustomize && \
    chmod g+rwX /.siege

USER 999
WORKDIR /home/argocd
CMD ["/bin/bash"]