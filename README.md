# Tools container image

A small Linux image with command-line tools often used next to **Argo CD** (for example as a config plugin sidecar) and on **OpenShift**. It is built for **amd64** and uses a Red Hat Universal Base Image.

## What’s inside

Roughly, you get:

- **OpenShift / Kubernetes:** `oc` and `kubectl` (from the OpenShift client bundle)
- **Helm** — packaging and templating charts  
- **Kustomize** — building manifests, including the **policy generator** plugin for Open Cluster Management–style workflows  
- **Argo CD CLI** (`argocd`)  
- **Argo Rollouts** kubectl plugin (`kubectl-argo-rollouts`)  
- **Siege** — simple HTTP load testing (with a bundled config file)  
- **Everyday utilities** — for example `git`, `jq`, `yq`, `tar`, `find`, and `gettext` (handy for scripts and templates)

Exact versions are defined in the `Dockerfile` when the image is built. The image version for published builds is taken from the **`VERSION`** file in this folder.

## Using it

This repository is meant for people who already know how they want to run the image (for example in a cluster or a CI pipeline). There is no step-by-step tutorial here.

If the project publishes container images, tags usually follow the **`VERSION`** file; **`latest`** may point at the most recent default-branch build. Check your registry for what is actually available.

## Support

This is a personal / best-effort project. **There is no service level agreement (SLA):** no guaranteed response time, uptime, or long-term maintenance. Use it at your own risk, test before you rely on it in production, and do not assume ongoing support or compatibility promises.

## License

See the `LICENSE` file in this repository.
