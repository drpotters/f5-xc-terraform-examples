# OpenShift Automated SMSv2 Site Provisioning

This automation provisions and destroys KubeVirt VirtualMachines and DataVolumes in parallel on OpenShift using the `oc` CLI. It supports resuming failed runs, tracks all resources in a state file, and allows for custom resource name prefixes.

---

## Prerequisites

- **Python 3.6+**
- **OpenShift CLI (`oc`)** installed and in your `$PATH`
- Access to an OpenShift cluster with KubeVirt and CDI installed
- The following environment variables must be set:

  - `OCP_URL`      — OpenShift API server URL (e.g. `https://api.xc-ocp.pdsea.f5net.com:6443`)
  - `OCP_USER`     — OpenShift username
  - `OCP_PASS`     — OpenShift password
  - `SITE_NAME_PREFIX` (optional) — Prefix for all DV/VM names (default: `ocp-test`)

Example:
```sh
export OCP_URL=https://api.xc-ocp.pdsea.f5net.com:6443
export OCP_USER=admin
export OCP_PASS=secret
export SITE_NAME_PREFIX=dtummidi-test
```

---

## Usage

### 1. Provision Resources

Run the main automation script to create DataVolumes and VMs:

```sh
python3 main.py -n <namespace> -b <base-dv> -c <count> -t <site-token>
```

- `-n, --namespace`   — Target OpenShift namespace that **already exists**
- `-b, --base-dv`     — Source/base **existing** DataVolume name to clone from
- `-c, --count`       — Number of VMs (and DVs) to create
- `-t, --token`       — F5XC SMSv2 site registration token

Optional:
- `--dv-template`     — Path to DataVolume template (default: `templates/dv.yaml`)
- `--vm-template`     — Path to VM template (default: `templates/vm.yaml`)
- `--max-workers`     — Max parallel workers (default: 3)

#### Example
```sh
python3 main.py -n f5xc-sqa -b base-image-rhel-9-2026-5-amd64 -c 3 -t <site-token>
```

- Names will be like `dtummidi-test-dv-xxxxx-0`, `dtummidi-test-vm-xxxxx-0` (if `SITE_NAME_PREFIX=dtummidi-test`)
- The script will resume from where it left off if interrupted (using `.infra_state.json`)

---

### 2. Destroy Resources

To delete all DVs and VMs created by this automation:

```sh
python3 destroy_infra.py
```

- Reads `.infra_state.json` to find and delete all tracked resources
- Deletes VMs first, then DVs
- Safe to re-run; only missing resources are skipped

---

## How It Works

- **Parallel creation:** DVs are created in parallel, then VMs are created in parallel once all DVs are ready.
- **Resumable:** If a run fails or is interrupted, re-running with the same parameters resumes from the last state.
- **State tracking:** All created resources are tracked in `.infra_state.json` for reliable cleanup.
- **Custom naming:** Resource names are prefixed with `SITE_NAME_PREFIX` (or `ocp-test` if unset).
- **No temp files:** All manifests are applied via stdin; no YAML files are written to disk.

---

## Troubleshooting

- If you change parameters (namespace, count, base-dv), a new run is started and previous resources are still tracked for cleanup.
- To force a clean slate, delete `.infra_state.json` before running create or destroy.
- If you see timeouts waiting for DVs or VMs, check OpenShift and storage backend health.
- Ensure your base DataVolume exists and is accessible in the target namespace.

---

## Example Output

```
=== Creating 3 DataVolumes in parallel ===
[DV] creating: dtummidi-dv-abcde-0
[DV] creating: dtummidi-dv-abcde-1
[DV] creating: dtummidi-dv-abcde-2
[DV] ready:  dtummidi-dv-abcde-0
[DV] ready:  dtummidi-dv-abcde-1
[DV] ready:  dtummidi-dv-abcde-2

=== Creating 3 VMs in parallel ===
[VM] creating:  dtummidi-vm-abcde-0 (uses dtummidi-dv-abcde-0)
[VM] creating:  dtummidi-vm-abcde-1 (uses dtummidi-dv-abcde-1)
[VM] creating:  dtummidi-vm-abcde-2 (uses dtummidi-dv-abcde-2)
[VM] created:   dtummidi-vm-abcde-0
[VM] created:   dtummidi-vm-abcde-1
[VM] created:   dtummidi-vm-abcde-2
[VM] ready:      dtummidi-vm-abcde-0 -> 10.0.0.101
[VM] ready:      dtummidi-vm-abcde-1 -> 10.0.0.102
[VM] ready:      dtummidi-vm-abcde-2 -> 10.0.0.103
```

---

## Notes
- The automation does not prompt for input; all parameters must be provided as arguments or environment variables.
- The state file `.infra_state.json` is required for proper cleanup and resume.
- For advanced use, see the script source for more options and details.