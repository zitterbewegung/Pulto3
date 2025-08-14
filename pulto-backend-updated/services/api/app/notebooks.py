
import nbformat
from nbclient import NotebookClient

def execute_notebook(path: str, timeout: int = 300) -> dict:
    nb = nbformat.read(path, as_version=4)
    client = NotebookClient(nb, timeout=timeout, kernel_name='python3', allow_errors=True)
    client.execute()
    nbformat.write(nb, path)
    return {"cells": [normalize_cell(c) for c in nb.cells]}

def extract_cells_from_path(path: str):
    nb = nbformat.read(path, as_version=4)
    return [normalize_cell(c) for c in nb.cells]

def normalize_cell(cell):
    return {
        "cell_type": cell.get("cell_type"),
        "source": "".join(cell.get("source", "")),
        "outputs": cell.get("outputs"),
    }
