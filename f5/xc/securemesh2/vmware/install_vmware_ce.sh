#!/usr/bin/env bash
set -euo pipefail

# Logging / Exit Helpers
Logger() {
    local level="$1"
    local msg="$2"
    printf "%s | %s | %s\n" "$(date +'%Y-%m-%d %H:%M:%S %Z')" "$level" "$msg"
}

ExitCall() {
    local level="$1"
    local msg="$2"
    Logger "$level" "$msg"
    exit 1
}

show_help() {
cat <<EOF
Usage:

Single Node:
bash $0 <ova_image_name> single <token>

Multi Node:
bash $0 <ova_image_name> multi <token>

Examples:
bash $0 f5xc-ce-9.2025.17-20250422075221.ova single dummyJWTToken
bash $0 f5xc-ce-9.2025.17-20250422075221.ova multi  dummyJWTToken

Required Environment Variables:

export VCENTER_USER="user@olympus"
export VCENTER_PASSWORD="password"

Options:
--help     Show help
EOF
exit 1
}

# Validate Env / Tools
GetEnvSetup() {

    [[ -n "${VCENTER_USER:-}" ]] || ExitCall ERROR "VCENTER_USER not set"
    [[ -n "${VCENTER_PASSWORD:-}" ]] || ExitCall ERROR "VCENTER_PASSWORD not set"

    # Resolve govc binary: config override, else PATH.
    if [[ -n "${govc_binary:-}" ]]; then
        [[ -x "$govc_binary" ]] || ExitCall ERROR "govc not executable: $govc_binary"
    elif command -v govc >/dev/null 2>&1; then
        govc_binary="$(command -v govc)"
    else
        ExitCall ERROR "govc not found in PATH and govc_binary not set in config"
    fi

    "$govc_binary" version >/dev/null 2>&1 \
        || ExitCall ERROR "govc is not working"

    # govc reads credentials from env vars only, never from the command line
    # or interactive prompts, so the '****' password echo problem cannot
    # happen. Export them once for all govc calls.
    export GOVC_URL="$vcenter_url"
    export GOVC_USERNAME="$VCENTER_USER"
    export GOVC_PASSWORD="$VCENTER_PASSWORD"
    export GOVC_INSECURE="true"
    export GOVC_DATACENTER="$datacenter"
    export GOVC_DATASTORE="$datastore"
    export GOVC_RESOURCE_POOL="/${datacenter}/host/${cluster}/Resources/${project}"
    export GOVC_NETWORK="$default_slo_network"

    # Fail fast if vCenter is unreachable / credentials are bad, with a clear
    # message instead of burning N deploy attempts.
    if ! "$govc_binary" about >/dev/null 2>&1; then
        ExitCall ERROR "govc cannot reach/auth to vCenter at ${vcenter_url} (check VCENTER_USER/VCENTER_PASSWORD and network)"
    fi

    # setsid is a belt-and-braces guard: govc itself does not prompt, but if
    # any wrapper in the chain (timeout, sudo, etc.) ever attached us back to
    # a tty, we still want no chance of an interactive prompt.
    if command -v setsid >/dev/null 2>&1; then
        notty_wrap=(setsid -w)
    else
        notty_wrap=()
    fi

    rm -f "${install_dir}/.vm_setup_file"
}

# Download OVA
DownloadAndCheckImage() {

    mkdir -p "$images_location"

    local full_path="${images_location}/${image_name}"

    if [[ -f "$full_path" ]]; then
        Logger INFO "Image already exists: $full_path"
        return
    fi

    Logger INFO "Downloading image: $image_name"

    wget --no-check-certificate \
         -O "$full_path" \
         "${download_source}/${image_name}" \
         || ExitCall ERROR "Failed downloading image"


    [[ -s "$full_path" ]] || ExitCall ERROR "Downloaded file is empty"
}

# Build a govc import spec JSON for the given VM. Written via python3 to
# guarantee correct JSON escaping for token / hostname values.
BuildImportSpec() {
    local vm_name="$1"
    local spec_file="$2"

    VM_NAME="$vm_name" \
    VES_TOKEN="$token" \
    NET_NAME="$default_slo_network" \
    python3 - "$spec_file" <<'PY'
import json, os, sys
spec = {
    "DiskProvisioning": "thin",
    "IPAllocationPolicy": "dhcpPolicy",
    "IPProtocol": "IPv4",
    "PropertyMapping": [
        {"Key": "guestinfo.ves.token",  "Value": os.environ["VES_TOKEN"]},
        {"Key": "guestinfo.hostname",   "Value": os.environ["VM_NAME"]},
    ],
    "NetworkMapping": [
        {"Name": "OUTSIDE", "Network": os.environ["NET_NAME"]},
    ],
    "MarkAsTemplate": False,
    "PowerOn": False,
    "InjectOvfEnv": True,
    "WaitForIP": False,
    "Name": os.environ["VM_NAME"],
}
with open(sys.argv[1], "w") as f:
    json.dump(spec, f, indent=2)
PY
}

# Run a govc command with timeout + notty wrap. Echoes output to caller via
# stdout (so callers can capture it), and returns govc's exit code.
RunGovc() {
    "${notty_wrap[@]}" timeout "$timeout" "$govc_binary" "$@" < /dev/null 2>&1
}

# Create VMware VM via govc.
CreateSmv2VMWare() {

    local vm_name="$1"
    local output
    local rc
    local instance_ip
    local attempt
    local max_attempts=3
    local backoff=15
    local spec_file

    spec_file="$(mktemp "${TMPDIR:-/tmp}/govc-spec-XXXXXX")"
    # shellcheck disable=SC2064
    trap "rm -f '$spec_file'" RETURN

    BuildImportSpec "$vm_name" "$spec_file"

    Logger INFO "Creating VM ==> $vm_name"

    # If a VM with this name already exists (e.g. previous failed deploy),
    # destroy it first to mimic ovftool's --overwrite. Ignore errors when it
    # doesn't exist.
    "$govc_binary" vm.destroy "$vm_name" >/dev/null 2>&1 || true

    for attempt in $(seq 1 "$max_attempts"); do
        Logger INFO "govc import.ova attempt ${attempt}/${max_attempts} for ${vm_name}"

        set +e
        output=$(RunGovc import.ova \
            -options="$spec_file" \
            -name="$vm_name" \
            "${images_location}/${image_name}")
        rc=$?
        set -e

        # Defensive scrub: govc never emits credentials, but if anything in
        # the pipeline ever did, strip it before logging.
        output=${output//"$VCENTER_PASSWORD"/<redacted-pass>}
        output=${output//"$VCENTER_USER"/<redacted-user>}

        if [[ $rc -eq 0 ]]; then
            break
        fi

        Logger WARN "govc import failed (rc=${rc}) on attempt ${attempt} for ${vm_name}"
        Logger WARN "govc output: ${output}"

        if [[ $attempt -lt $max_attempts ]]; then
            Logger INFO "Retrying in ${backoff}s"
            # Clean partial VM before retry.
            "$govc_binary" vm.destroy "$vm_name" >/dev/null 2>&1 || true
            sleep "$backoff"
            backoff=$(( backoff * 2 ))
        fi
    done

    if [[ $rc -ne 0 ]]; then
        ExitCall ERROR "VM creation failed for $vm_name after ${max_attempts} attempts"
    fi

    # Resize CPU / memory then power on.
    if ! RunGovc vm.change -vm="$vm_name" -c=8 -m=32768 >/dev/null; then
        ExitCall ERROR "Failed to reconfigure CPU/memory for $vm_name"
    fi

    if ! RunGovc vm.power -on=true "$vm_name" >/dev/null; then
        ExitCall ERROR "Failed to power on $vm_name"
    fi

    # Wait for guest IP (govc handles its own timeout).
    instance_ip=$(RunGovc vm.ip -wait=10m "$vm_name" | tr -d '[:space:]' || true)

    Logger INFO "Created VM '${vm_name}' IP='${instance_ip:-unknown}'"

    echo "$vm_name" >> "${install_dir}/.vm_setup_file"
}

# Main
[[ "${1:-}" == "--help" ]] && show_help
[[ $# -lt 3 ]] && show_help

image_name="$1"
ver_type="$2"
token="$3"

install_dir="$(cd "$(dirname "$0")" && pwd)"

config_file="${install_dir}/config.properties"

[[ -f "$config_file" ]] || ExitCall ERROR "Missing config file: $config_file"

# shellcheck disable=SC1090
source "$config_file"

# govc takes credentials via GOVC_USERNAME / GOVC_PASSWORD env vars set in
# GetEnvSetup, so no URL encoding of the password is needed (and we never put
# the password on a command line or in a URL).

shelluser="$(whoami | tr -cd '[:alnum:]')"


random_string="$(date +%s%N | sha256sum | head -c4)"

if [[ "$shelluser" != "jenkins" && "$shelluser" != "root" ]]; then
    project_prefix="${shelluser}-${random_string}"
else
    project_prefix="xc-qa-auto-${random_string}"
fi

GetEnvSetup
DownloadAndCheckImage

case "$ver_type" in
    single)
        CreateSmv2VMWare "$project_prefix"
        ;;

    multi)
        VM_COUNT=3
        for i in $(seq 1 "$VM_COUNT"); do
            CreateSmv2VMWare "${project_prefix}-${i}"
        done
        ;;

    *)
        show_help
        ;;
esac

Logger INFO "Completed successfully"