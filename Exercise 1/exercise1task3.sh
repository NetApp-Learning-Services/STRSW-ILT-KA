#!/usr/bin/env bash
# This script has been written for this exercise environment
# and is not intended to be used in a production environment.
# Execute by: ./exercise0Task4.sh

set -euo pipefail

DIR="/home/user/.kube"
PASS="Netapp1!"
CERT="/tmp/netapp-reg.crt"
REGISTRY_HOST="dockreg.labs.lod.netapp.com:443"

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

# --- Suggestion 1: install prerequisites only if missing ---
ensure_cmd() {
  local cmd="$1"
  local pkg="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y "$pkg"
  fi
}

ensure_cmd sshpass sshpass
ensure_cmd openssl openssl
ensure_cmd kubectl kubectl

# --- Function to get node names from a kubeconfig file ---
get_nodes () {
  local kubeconfig="$1"
  KUBECONFIG="$kubeconfig" kubectl get nodes \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
}

# --- Get nodes from each cluster BEFORE deleting temp kubeconfigs ---
NODES1="$(get_nodes "$DIR"/config)"

ALL_NODES="$(printf "%s\n%s\n" "$NODES1" | awk 'NF' | sort -u)"

# --- Suggestion 2: print the discovered node list ---
echo "Discovered nodes (deduplicated):"
echo "$ALL_NODES"
echo

# --- Fetch the TLS certificate chain presented by the registry proxy ---
openssl s_client -showcerts -connect "$REGISTRY_HOST" </dev/null \
  | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > "$CERT"

# --- Copy cert to each node, update CA store, restart containerd ---
for NODE in $ALL_NODES; do
  echo "Updating trust + restarting containerd on: $NODE"

  sshpass -p "$PASS" scp "${SSH_OPTS[@]}" \
    "$CERT" "root@${NODE}:/usr/local/share/ca-certificates/netapp-registry.crt"

  sshpass -p "$PASS" ssh "${SSH_OPTS[@]}" "root@${NODE}" \
    "update-ca-certificates && systemctl restart containerd"
done

echo
echo "Done. Registry certificate installed and containerd restarted on all discovered nodes."