import os
import subprocess
import sys


class OcCommandError(RuntimeError):
    """Raised when an `oc` command fails."""


def run_cmd(cmd, check=True, input_data=None):
    # Run a shell command. Raises OcCommandError instead of exiting.
    result = subprocess.run(
        cmd,
        shell=True,
        capture_output=True,
        text=True,
        input=input_data,
    )
    if check and result.returncode != 0:
        raise OcCommandError(
            f"Command failed ({result.returncode}): {cmd}\n{result.stderr.strip()}"
        )
    return result.stdout.strip()


def check_oc_installed():
    try:
        subprocess.run(
            "oc version --client",
            shell=True,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        print("oc CLI not installed or not in PATH")
        sys.exit(1)


def oc_login():
    url = os.getenv("OCP_URL")
    user = os.getenv("OCP_USER")
    password = os.getenv("OCP_PASS")

    if not all([url, user, password]):
        print("Missing env vars: OCP_URL / OCP_USER / OCP_PASS")
        sys.exit(1)

    try:
        run_cmd(
            f"oc login {url} -u {user} -p {password} --insecure-skip-tls-verify"
        )
    except OcCommandError as exc:
        print(exc)
        sys.exit(1)


def set_namespace(ns):
    try:
        run_cmd(f"oc project {ns}")
    except OcCommandError as exc:
        print(exc)
        sys.exit(1)
