#!/bin/bash
set -euo pipefail

# If a dependency is need, will say which then exit script
need_deps() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1" >&2
    exit 1
  }
}

need_env() {
  printenv "$1" >/dev/null 2>&1 || {
    echo "Missing required EXPORTED env var: $1" >&2
    echo "Example: export $1='...'" >&2
    exit 1
  }
}

# Check for dependencies
check_deps() {
  need_deps omnictl
  need_deps kubectl
  need_deps cilium
  need_deps flux
  need_deps sops
  need_deps age
  echo "Dependencies present"
}

check_env() {
  need_env GITHUB_TOKEN
  need_env AGE_PRIVATE
  echo "Required env vars exported"
}

CLUSTER_NAME="${CLUSTER_NAME:-homelab-staging}"
export CLUSTER_NAME

omni_cluster() {
  local template="${OMNI_TEMPLATE_FILE:-./cluster-template.yaml}"

  echo "Validating Omni cluster template"
  omnictl cluster template validate -f "$template"

  echo "Applying template to Omni"
  omnictl cluster template sync -f "$template"

  echo "Waiting for cluster to be ready (template status)"
  omnictl cluster template status -f "$template" -w "10m"
}

omni_kubeconfig() {
  local kube_dir="${HOME}/.kube"
  local kube_file="${kube_dir}/${CLUSTER_NAME}.yaml"

  mkdir -p "$kube_dir"

  echo "Writing kubeconfig for cluster '$CLUSTER_NAME' to: $kube_file"
  omnictl kubeconfig "$kube_file" -c "$CLUSTER_NAME" --merge=false --force

  echo "Quick check:"
  kubectl --kubeconfig "$kube_file" get nodes

  export KUBECONFIG="$kube_file"
  echo "KUBECONFIG set to $KUBECONFIG"
}

cilium_install() {
  local values_file="${CILIUM_VALUES_FILE:-../../infrastructure/controllers/staging/cilium/values.yaml}"

  [[ -f "$values_file" ]] || {
    echo "Cilium values file not found: $values_file" >&2
    exit 1
  }

  #cilium install -f "$values_file"

  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml

  cilium install \
    --set ipam.mode=kubernetes \
    --set kubeProxyReplacement=true \
    --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
    --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
    --set cgroup.autoMount.enabled=false \
    --set cgroup.hostRoot=/sys/fs/cgroup \
    --set k8sServiceHost=localhost \
    --set k8sServicePort=7445 \
    --set gatewayAPI.enabled=true \
    --set gatewayAPI.enableAlpn=true \
    --set gatewayAPI.enableAppProtocol=true

  echo "Waiting for Cilium to be healthy"
  cilium status --wait
}

flux_bootstrap() {
  local github_owner="${GITHUB_OWNER:-RamonCollazo}"
  local github_repo="${GITHUB_REPO:-kube-homelab}"
  local github_branch="${GITHUB_BRANCH:-main}"
  local github_path="${GITHUB_PATH:-clusters/staging}"

  echo "Bootstrapping Flux to GitHub repo"
  flux bootstrap github \
    --token-auth \
    --owner="$github_owner" \
    --repository="$github_repo" \
    --branch="$github_branch" \
    --path="$github_path" \
    --personal
}

age_secret() {
  echo "Creating/updating secret flux-system/sops-age"
  kubectl create secret generic sops-age \
    --namespace=flux-system \
    --from-literal=age.agekey="${AGE_PRIVATE}"

  echo "Secret flux-system/sops-age created"
}

main() {
  check_deps
  check_env
  omni_cluster
  omni_kubeconfig
  cilium_install
  flux_bootstrap
  age_secret
}

main "$@"
