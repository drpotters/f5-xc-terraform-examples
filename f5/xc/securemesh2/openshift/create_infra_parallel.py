"""
Two-phase parallel provisioning:

    Phase 1: create N DataVolumes in parallel, wait for ALL to reach
             ``Succeeded``.
    Phase 2: create N VirtualMachines in parallel (DV-i paired with VM-i),
             wait for each VMI to expose an IP.

If any DV fails in phase 1 the run is aborted and no VMs are created.
"""

import json
import os
import random
import string
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

from oc_utils import OcCommandError, run_cmd

# State file (next to this script) that records every DV/VM created.
# destroy_infra.py reads this file to tear down resources without
# requiring any user input.
STATE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".infra_state.json")
_state_lock = threading.Lock()

def _load_state():
    if not os.path.exists(STATE_FILE):
        return {"resources": []}
    try:
        with open(STATE_FILE, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {"resources": []}


def _save_state(state):
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=2)
    os.replace(tmp, STATE_FILE)


def _record_resource(kind, name, namespace, run_id):
    """Append a resource record to the state file (thread-safe, dedup)."""
    with _state_lock:
        state = _load_state()
        resources = state.setdefault("resources", [])
        # Avoid duplicate entries on resume.
        for r in resources:
            if (r["kind"] == kind
                    and r["name"] == name
                    and r["namespace"] == namespace):
                return
        resources.append({
            "kind": kind,
            "name": name,
            "namespace": namespace,
            "run_id": run_id,
        })
        _save_state(state)


def _resource_exists(kind, name, namespace):
    """Return True if the resource currently exists in the cluster."""
    try:
        run_cmd(
            f"oc get {kind.lower()} {name} -n {namespace} "
            f"-o name"
        )
        return True
    except OcCommandError:
        return False


def _set_current_run(run_id, namespace, count, base_dv, phase):
    with _state_lock:
        state = _load_state()
        state["current_run"] = {
            "run_id": run_id,
            "namespace": namespace,
            "count": count,
            "base_dv": base_dv,
            "phase": phase,  # "dv" or "vm"
        }
        _save_state(state)


def _clear_current_run():
    with _state_lock:
        state = _load_state()
        state.pop("current_run", None)
        _save_state(state)


def random_suffix(n=5):
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=n))


def render_template(template_path, replacements):
    #Render a template by replacing keys with values.
    with open(template_path, "r") as f:
        content = f.read()

    for k in sorted(replacements, key=len, reverse=True):
        content = content.replace(k, replacements[k])

    return content


def _apply_manifest(manifest):
    # Apply a manifest via stdin to avoid temp-file races.
    run_cmd("oc apply -f -", input_data=manifest)


# DataVolume
def create_dv(template_path, dv_name, namespace, base_dv):
    manifest = render_template(
        template_path,
        {
            "DV_NAMESPACE": namespace,
            "BASE_DV": base_dv,
            "DV_NAME": dv_name,
        },
    )
    _apply_manifest(manifest)


def wait_for_dv(namespace, dv_name, timeout=3600, poll=15):
    start = time.time()
    while True:
        try:
            phase = run_cmd(
                f"oc get dv {dv_name} -n {namespace} "
                f"-o jsonpath='{{.status.phase}}'"
            )
        except OcCommandError:
            phase = ""

        if phase == "Succeeded":
            print(f"[DV] ready:  {dv_name}")
            return
        if phase in {"Failed", "Unknown"}:
            raise RuntimeError(f"DV {dv_name} entered phase {phase}")
        if time.time() - start > timeout:
            raise TimeoutError(
                f"Timeout ({timeout}s) waiting for DV {dv_name} "
                f"(last phase: {phase or 'unknown'})"
            )
        time.sleep(poll)


def _get_prefix():
    return os.environ.get("SITE_NAME_PREFIX", "ocp-test")

def _provision_dv(index, namespace, dv_template, base_dv, run_id):
    prefix = _get_prefix()
    dv_name = f"{prefix}-dv-{run_id}-{index}"
    print(f"[DV] creating: {dv_name}")

    # Check if base DataVolume exists before proceeding
    if not _resource_exists("DataVolume", base_dv, namespace):
        raise RuntimeError(f"Base DataVolume '{base_dv}' does not exist in namespace '{namespace}'")

    if not _resource_exists("DataVolume", dv_name, namespace):
        create_dv(dv_template, dv_name, namespace, base_dv)
        _record_resource("DataVolume", dv_name, namespace, run_id)
    else:
        _record_resource("DataVolume", dv_name, namespace, run_id)
    wait_for_dv(namespace, dv_name)
    return index, dv_name


# CE node VM
def create_vm(template_path, vm_name, dv_name, token, namespace):
    manifest = render_template(
        template_path,
        {
            "VM_NAMESPACE": namespace,
            "VM_NAME": vm_name,
            "DV_NAME": dv_name,
            "TOKEN": token,
        },
    )
    _apply_manifest(manifest)


def wait_for_vm_ip(namespace, vm_name, timeout=600, poll=5):
    start = time.time()
    fallback_grace = 300  # seconds to wait for outside-net before fallback
    fallback_start = None
    while True:
        try:
            iface_lines = run_cmd(
                f"oc get vmi {vm_name} -n {namespace} "
                f"-o jsonpath='{{range .status.interfaces[*]}}{{.name}} {{.ipAddress}}\\n{{end}}'"
            )
        except OcCommandError:
            iface_lines = ""

        outside_ip = None
        fallback_ip = None
        saw_outside = False
        for line in iface_lines.replace("\\n", "\n").splitlines():
            parts = line.strip().split()
            if len(parts) == 2:
                name, ip = parts
                if name == "outside-net":
                    saw_outside = True
                    if ip and "." in ip:
                        outside_ip = ip
                elif not fallback_ip and ip and "." in ip:
                    fallback_ip = ip

        if outside_ip:
            print(f"[VM] ready:      {vm_name} -> {outside_ip}")
            return outside_ip

        # If outside-net exists but no IP, start fallback timer
        if saw_outside and not outside_ip and fallback_ip:
            if fallback_start is None:
                fallback_start = time.time()
            elif time.time() - fallback_start > fallback_grace:
                print(f"[VM] fallback:   {vm_name} -> {fallback_ip} (outside-net IP not leased after {fallback_grace}s)")
                return fallback_ip
        else:
            fallback_start = None  # reset if outside-net not present or fallback not available

        if time.time() - start > timeout:
            raise TimeoutError(
                f"Timeout ({timeout}s) waiting for IPv4 for VM {vm_name}"
            )
        time.sleep(poll)


def _provision_vm(index, namespace, vm_template, dv_name, token, run_id):
    prefix = _get_prefix()
    vm_name = f"{prefix}-vm-{run_id}-{index}"
    print(f"[VM] creating:  {vm_name} (uses {dv_name})")
    created = False
    if not _resource_exists("VirtualMachine", vm_name, namespace):
        create_vm(vm_template, vm_name, dv_name, token, namespace)
        _record_resource("VirtualMachine", vm_name, namespace, run_id)
        created = True
    else:
        _record_resource("VirtualMachine", vm_name, namespace, run_id)
    print(f"[VM] created:   {vm_name}")
    ip = wait_for_vm_ip(namespace, vm_name)
    return vm_name, ip


# Orchestrator
def provision_all(count, namespace, dv_template, vm_template, base_dv, token,
                  max_workers=5):
    #Two-phase parallel provisioning. Returns list[(vm_name, ip)].
    workers = min(count, max_workers)

    # ------------------------------------------------------------------
    # Resume detection: if a previous run with identical (namespace,
    # count, base_dv) is still tracked in the state file, reuse its
    # run_id so existing DVs/VMs are picked up instead of recreated.
    # ------------------------------------------------------------------
    state = _load_state()
    current = state.get("current_run")
    if (current
            and current.get("namespace") == namespace
            and current.get("count") == count
            and current.get("base_dv") == base_dv):
        run_id = current["run_id"]
        print(f"Resuming previous run: run_id={run_id} "
              f"(phase was: {current.get('phase')})")
    else:
        run_id = random_suffix()
        print(f"Starting new run: run_id={run_id}")

    _set_current_run(run_id, namespace, count, base_dv, phase="dv")

    # First: DataVolumes
    print(f"\n=== Creating {count} DataVolumes in parallel ===")
    dv_map = {}  # index -> dv_name
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {
            pool.submit(_provision_dv, i, namespace, dv_template, base_dv, run_id): i
            for i in range(count)
        }
        for fut in as_completed(futures):
            idx = futures[fut]
            try:
                index, dv_name = fut.result()
                dv_map[index] = dv_name
            except Exception as exc:
                print(f"[DV] FAILED index={idx}: {exc}")

    if len(dv_map) != count:
        # Keep current_run in state so the next invocation can resume.
        raise RuntimeError(
            f"DataVolume phase failed: only {len(dv_map)}/{count} succeeded; "
            f"re-run the same command to resume."
        )

    _set_current_run(run_id, namespace, count, base_dv, phase="vm")

    # Second: VirtualMachines
    print(f"\n=== Creating {count} VMs in parallel ===")
    results = []
    failed = 0
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {
            pool.submit(
                _provision_vm,
                i, namespace, vm_template, dv_map[i], token, run_id,
            ): i
            for i in range(count)
        }
        for fut in as_completed(futures):
            idx = futures[fut]
            try:
                results.append(fut.result())
            except Exception as exc:
                failed += 1
                print(f"[VM] FAILED index={idx} (dv={dv_map[idx]}): {exc}")

    if failed == 0:
        # Run fully complete; clear the in-progress marker but keep
        # the resource list so destroy_infra.py can clean up later.
        _clear_current_run()

    return results
