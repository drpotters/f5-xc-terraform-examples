"""Tear down all DVs and VMs previously created by create_infra_parallel.

Reads `.infra_state.json` (written during creation) and deletes every
recorded resource. No user input required.

Usage:
    python3 destroy_infra.py
"""

import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

from oc_utils import OcCommandError, check_oc_installed, oc_login, run_cmd
from create_infra_parallel import STATE_FILE, _load_state, _save_state


def _delete_resource(kind, name, namespace):
    cmd = (
        f"oc delete {kind.lower()} {name} -n {namespace} "
        f"--ignore-not-found --wait=false"
    )
    try:
        run_cmd(cmd)
        print(f"[DEL] {kind}/{name} (ns={namespace})")
        return True
    except OcCommandError as exc:
        print(f"[ERR] {kind}/{name} (ns={namespace}): {exc}")
        return False


def main():
    if not os.path.exists(STATE_FILE):
        print(f"No state file at {STATE_FILE}; nothing to destroy.")
        return

    state = _load_state()
    resources = state.get("resources", [])
    if not resources:
        print("State file is empty; nothing to destroy.")
        return

    check_oc_installed()
    oc_login()

    # Delete VMs first so they release the DataVolumes cleanly,
    # then delete DataVolumes (and the underlying PVCs).
    vms = [r for r in resources if r["kind"] == "VirtualMachine"]
    dvs = [r for r in resources if r["kind"] == "DataVolume"]
    others = [r for r in resources
              if r["kind"] not in {"VirtualMachine", "DataVolume"}]

    failed = []

    def _run_phase(label, batch):
        if not batch:
            return
        print(f"\n=== Deleting {len(batch)} {label}(s) in parallel ===")
        workers = min(len(batch), 5)
        with ThreadPoolExecutor(max_workers=workers) as pool:
            futures = {
                pool.submit(_delete_resource, r["kind"], r["name"], r["namespace"]): r
                for r in batch
            }
            for fut in as_completed(futures):
                r = futures[fut]
                if not fut.result():
                    failed.append(r)

    _run_phase("VirtualMachine", vms)
    _run_phase("DataVolume", dvs)
    _run_phase("Other", others)

    if failed:
        print(f"\n{len(failed)} resource(s) failed to delete; "
              f"keeping state file for retry.")
        # Keep only the failed entries so a re-run targets just those.
        _save_state({"resources": failed})
        sys.exit(1)

    # All clean — wipe the state file.
    try:
        os.remove(STATE_FILE)
    except OSError:
        pass
    print("\nAll recorded resources deleted. State file cleared.")


if __name__ == "__main__":
    main()
