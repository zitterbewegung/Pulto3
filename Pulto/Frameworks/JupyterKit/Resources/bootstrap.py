import sys, os, argparse, pathlib

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, required=True)
    ap.add_argument("--notebook-dir", type=str, required=True)
    ap.add_argument("--ui", choices=["lab", "notebook"], default="lab")
    args = ap.parse_args()

    nbdir = pathlib.Path(args.notebook_dir)
    nbdir.mkdir(parents=True, exist_ok=True)

    # site-packages is in the main bundle Resources/Jupyter/site-packages
    # PYTHONPATH is already pointing there via the Swift layer.

    module = "jupyterlab" if args.ui == "lab" else "notebook"

    cmd = [
        sys.executable, "-m", module,
        f"--ServerApp.port={args.port}",
        "--ServerApp.ip=127.0.0.1",
        "--ServerApp.open_browser=False",
        f"--ServerApp.root_dir={nbdir}",
        "--ServerApp.allow_remote_access=False",
        "--ServerApp.allow_origin=",
        "--ServerApp.disable_check_xsrf=False",
        "--ServerApp.token=''",
        "--ServerApp.password=''",
        "--ServerApp.quit_button=True",
        "--ServerApp.base_url=/"
    ]
    os.execv(sys.executable, cmd)

if __name__ == "__main__":
    main()
