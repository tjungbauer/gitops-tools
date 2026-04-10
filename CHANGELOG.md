# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The version in **`VERSION`** matches the container image tag published by the GitHub Actions workflow (alongside **`latest`**).

## [Unreleased]

### Changed

- **Dockerfile:** third-party install step uses a **BuildKit heredoc** (`# syntax=docker/dockerfile:1`) for clearer layout; requires **BuildKit** (default with `docker buildx` / current Docker Engine).

## Releases

### [1.0.2] — 2026-04-10

#### Removed

- **Siege** (HTTP load tester), **`siege.conf`**, **`/.siege`**, and **EPEL 9**. EPEL was only required for Siege and the **`yq` RPM**; **`yq`** is now the upstream **mikefarah/yq** Linux amd64 binary pinned by **`YQ_VERSION`**.

#### Changed

- **Command line tools** updated Helm to latest v3 version

### [1.0.1] — 2026-04-03

#### Security

- **Argo CD CLI** updated to **3.3.6** so embedded **gRPC** is at least **1.79.3**, addressing **GHSA-p77j-4mvh-x3m3** (authorization bypass via malformed `:path`) as reported by container scanners such as Quay Security / Clair.
- **Dockerfile:** added **`OCP_CLIENT_VERSION`** build argument (default **`stable`**) so the **OpenShift client** tarball URL uses `.../clients/ocp/${OCP_CLIENT_VERSION}/...`. Pin to a specific release (e.g. **`4.17.12`**) to align **`oc`/`kubectl`** with your cluster and refresh embedded dependencies that container scanners (e.g. Quay / Clair) report against **`k8s.io/kubernetes`** and related Go modules.

#### Changed

- **Dockerfile:** **UBI 9** minimal base; **EPEL 9** for packages such as **siege**; remote installs use **`curl -fsSL`**. Pinned CLI/tool versions in the image include **Helm 3.19.4**, **Kustomize 5.8.1**, **Argo Rollouts 1.8.4**, and **Policy Generator 1.17.1** (see `Dockerfile` `ARG` defaults).
- **OpenShift:** runtime user **999** (`argocd`) with primary group **0**; **`chgrp` / `chmod`** on **`/home/argocd`**, **`/etc/kustomize`**, and **`/.siege`** so arbitrary UID with GID **0** can use home, Kustomize plugins, and siege config.
- **CI:** workflow publishes **`quay.io/tjungbau/gitops-tools`** with tags **`$VERSION`**, **`latest`**, and **`sha-<short>`** when **`VERSION`** changes on the default branch.

### [1.0.0]

- Initial semver baseline for the GitOps tools container image.
