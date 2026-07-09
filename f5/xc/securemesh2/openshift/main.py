import argparse
import sys
from pathlib import Path

from oc_utils import check_oc_installed, oc_login, set_namespace
from create_infra_parallel import provision_all


def parse_args():
    parser = argparse.ArgumentParser(
        description="Automation to provision CE DataVolumes and VMs in parallel on OpenShift.",
    )
    parser.add_argument("-n", "--namespace", required=True,
                        help="Target OpenShift namespace.")
    parser.add_argument("-b", "--base-dv", required=True,
                        help="Source/base DataVolume name to clone from.")
    parser.add_argument("-c", "--count", type=int, required=True,
                        help="Number of VMs (and DVs) to create.")
    parser.add_argument("-t", "--token", required=True,
                        help="F5XC site registration token.")
    parser.add_argument("--dv-template", default="templates/dv.yaml",
                        help="Path to the DataVolume template.")
    parser.add_argument("--vm-template", default="templates/vm.yaml",
                        help="Path to the VirtualMachine template.")
    parser.add_argument("--max-workers", type=int, default=3,
                        help="Max concurrent workers per phase.")

    # Print help and exit cleanly when invoked with no arguments.
    if len(sys.argv) == 1:
        parser.print_help(sys.stderr)
        sys.exit(0)

    args = parser.parse_args()

    if args.count < 1:
        parser.error("--count must be >= 1")
    return args


def main():
    args = parse_args()

    check_oc_installed()
    oc_login()
    set_namespace(args.namespace)

    # Verify namespace exists before proceeding
    import subprocess
    try:
        subprocess.run([
            "oc", "get", "namespace", args.namespace
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        print(f"ERROR: Namespace '{args.namespace}' does not exist.", file=sys.stderr)
        sys.exit(1)
    
    repo_root = Path(__file__).resolve().parents[2]
    templates_dir = repo_root / "securemesh2" / "openshift" / "templates"
    
    dv_template = Path(args.dv_template)
    vm_template = Path(args.vm_template)
    
    if not dv_template.is_absolute():
        dv_template = templates_dir / dv_template.name
    
    if not vm_template.is_absolute():
        vm_template = templates_dir / vm_template.name

    results = provision_all(
        count=args.count,
        namespace=args.namespace,
        dv_template=dv_template,
        vm_template=vm_template,
        base_dv=args.base_dv,
        token=args.token,
        max_workers=args.max_workers,
    )

    print("\n==============================")
    print("  VM Provisioning Complete")
    print("==============================\n")

    for name, ip in results:
        print(f"{name:30} -> {ip}")


if __name__ == "__main__":
    main()

