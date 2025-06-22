# Notebook Server Design for Spatial Visualization
# This server handles both chart extraction and VisionOS environment restoration

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import json
import base64
import io
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt
import numpy as np
from typing import Dict, List, Any, Optional
import tempfile
import nbformat
from nbconvert import PythonExporter
import ast
import sys
from contextlib import redirect_stdout, redirect_stderr
from datetime import datetime

app = FastAPI(title="Spatial Notebook Server")

# MARK: - Main Endpoints

@app.post("/convert/{notebook_name}")
async def convert_notebook(notebook_name: str, file: UploadFile = File(...)):
    """
    Main endpoint that handles notebook conversion.
    Can process both regular notebooks (extracts charts) and VisionOS notebooks (preserves spatial data)
    """
    try:
        # Read the uploaded notebook
        content = await file.read()
        notebook_data = json.loads(content)

        # Check if this is a VisionOS notebook
        metadata = notebook_data.get("metadata", {})
        visionos_export = metadata.get("visionos_export")

        if visionos_export:
            # This is a VisionOS notebook - preserve spatial data
            return await handle_visionos_notebook(notebook_data, notebook_name)
        else:
            # Regular notebook - extract charts
            return await extract_charts_from_notebook(notebook_data, notebook_name)

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/notebooks/{notebook_name}")
async def get_notebook_info(notebook_name: str):
    """Get information about a stored notebook"""
    # Implementation depends on your storage strategy
    # Could use a database, file system, or cloud storage
    notebook_info = {
        "name": notebook_name,
        "cells": 0,  # Count from stored data
        "charts": 0,  # Count extracted charts
        "has_spatial_data": False,
        "last_modified": datetime.now().isoformat()
    }
    return notebook_info

@app.put("/notebooks/{notebook_name}/cells/{cell_index}/spatial")
async def update_cell_spatial_position(
    notebook_name: str,
    cell_index: int,
    spatial_data: Dict[str, float]
):
    """Update spatial position for a specific cell"""
    # Expected spatial_data format:
    # {
    #   "x": 1.0, "y": 1.0, "z": 1.0,
    #   "pitch": 0.0, "yaw": 0.0, "roll": 0.0
    # }

    # Store the spatial position (implementation depends on storage)
    return {"status": "updated", "cell_index": cell_index, "spatial": spatial_data}

# MARK: - Chart Extraction Functions

async def extract_charts_from_notebook(
    notebook_data: Dict[str, Any],
    notebook_name: str
) -> Dict[str, List[str]]:
    """
    Extract charts from a regular Jupyter notebook
    Returns base64-encoded images grouped by cell
    """
    try:
        # Parse notebook
        notebook = nbformat.from_dict(notebook_data)
        charts = {}

        # Convert to Python code
        exporter = PythonExporter()
        python_code, _ = exporter.from_notebook_node(notebook)

        # Execute cells and capture plots
        for i, cell in enumerate(notebook.cells):
            if cell.cell_type == 'code':
                chart_images = await execute_cell_and_capture_plots(
                    cell.source,
                    cell_index=i
                )
                if chart_images:
                    charts[f"chartKey_{i}"] = chart_images

        # Add any chart positions from metadata
        if "chartPositions" in notebook_data.get("metadata", {}):
            # Preserve position data in response
            charts["_positions"] = notebook_data["metadata"]["chartPositions"]

        return charts

    except Exception as e:
        print(f"Error extracting charts: {e}")
        return {"error": str(e)}

async def execute_cell_and_capture_plots(
    code: str,
    cell_index: int
) -> List[str]:
    """
    Execute a code cell and capture any matplotlib plots as base64 images
    """
    captured_plots = []

    # Create a clean namespace for execution
    namespace = {
        'np': np,
        'plt': plt,
        '__name__': '__main__'
    }

    # Capture stdout/stderr
    stdout_buffer = io.StringIO()
    stderr_buffer = io.StringIO()

    try:
        # Clear any existing plots
        plt.close('all')

        # Execute the code
        with redirect_stdout(stdout_buffer), redirect_stderr(stderr_buffer):
            exec(code, namespace)

        # Check if any plots were created
        figures = [plt.figure(i) for i in plt.get_fignums()]

        for fig in figures:
            # Convert plot to base64
            buf = io.BytesIO()
            fig.savefig(buf, format='png', dpi=150, bbox_inches='tight')
            buf.seek(0)
            img_base64 = base64.b64encode(buf.read()).decode('utf-8')
            captured_plots.append(img_base64)
            plt.close(fig)

    except Exception as e:
        print(f"Error executing cell {cell_index}: {e}")
        # Could return error visualization here

    return captured_plots

# MARK: - VisionOS Notebook Handling

async def handle_visionos_notebook(
    notebook_data: Dict[str, Any],
    notebook_name: str
) -> Dict[str, Any]:
    """
    Handle VisionOS notebooks that contain spatial window data
    Preserves the notebook structure while potentially updating positions
    """
    # Extract VisionOS metadata
    metadata = notebook_data.get("metadata", {})
    visionos_data = metadata.get("visionos_export", {})

    # Process cells that contain window data
    processed_cells = []
    window_count = 0

    for cell in notebook_data.get("cells", []):
        cell_metadata = cell.get("metadata", {})

        # Check if this cell represents a VisionOS window
        if "visionos_window" in cell_metadata:
            window_info = cell_metadata["visionos_window"]
            window_count += 1

            # Could process or validate window data here
            processed_cells.append({
                "window_id": window_info.get("id"),
                "window_type": window_info.get("type"),
                "position": window_info.get("position"),
                "content_preview": cell.get("source", "")[:100] + "..."
            })

    # Return the notebook with any updates
    response = {
        "nbformat": notebook_data.get("nbformat", 4),
        "nbformat_minor": notebook_data.get("nbformat_minor", 5),
        "metadata": metadata,
        "cells": notebook_data.get("cells", []),
        "_processed_info": {
            "window_count": window_count,
            "processed_cells": processed_cells,
            "timestamp": datetime.now().isoformat()
        }
    }

    return response

# MARK: - Storage Functions (Example implementations)

class NotebookStorage:
    """Example storage class - implement based on your needs"""

    def __init__(self):
        # In-memory storage for demo
        self.notebooks = {}
        self.spatial_positions = {}

    def save_notebook(self, name: str, data: Dict[str, Any]):
        self.notebooks[name] = {
            "data": data,
            "last_modified": datetime.now()
        }

    def get_notebook(self, name: str) -> Optional[Dict[str, Any]]:
        return self.notebooks.get(name)

    def update_spatial_position(
        self,
        notebook_name: str,
        cell_index: int,
        position: Dict[str, float]
    ):
        key = f"{notebook_name}:{cell_index}"
        self.spatial_positions[key] = position

storage = NotebookStorage()

# MARK: - Additional Endpoints

@app.post("/notebooks/{notebook_name}/analyze")
async def analyze_notebook(notebook_name: str, file: UploadFile = File(...)):
    """
    Analyze a notebook without executing it
    Returns information about cells, imports, and potential visualizations
    """
    content = await file.read()
    notebook_data = json.loads(content)

    analysis = {
        "total_cells": len(notebook_data.get("cells", [])),
        "code_cells": 0,
        "markdown_cells": 0,
        "has_plots": False,
        "imports": set(),
        "window_cells": 0,
        "has_visionos_data": False
    }

    # Check for VisionOS data
    metadata = notebook_data.get("metadata", {})
    if "visionos_export" in metadata:
        analysis["has_visionos_data"] = True
        analysis["visionos_metadata"] = metadata["visionos_export"]

    # Analyze cells
    for cell in notebook_data.get("cells", []):
        if cell["cell_type"] == "code":
            analysis["code_cells"] += 1

            # Check for plotting code
            source = cell.get("source", "")
            if isinstance(source, list):
                source = "".join(source)

            if any(plot_indicator in source for plot_indicator in
                   ["plt.", "plot(", "scatter(", "bar(", "hist("]):
                analysis["has_plots"] = True

            # Extract imports
            try:
                tree = ast.parse(source)
                for node in ast.walk(tree):
                    if isinstance(node, ast.Import):
                        for alias in node.names:
                            analysis["imports"].add(alias.name)
                    elif isinstance(node, ast.ImportFrom):
                        analysis["imports"].add(node.module)
            except:
                pass

        elif cell["cell_type"] == "markdown":
            analysis["markdown_cells"] += 1

        # Check for VisionOS window cells
        if "visionos_window" in cell.get("metadata", {}):
            analysis["window_cells"] += 1

    analysis["imports"] = list(analysis["imports"])
    return analysis

@app.post("/charts/generate")
async def generate_test_charts():
    """Generate test charts for development"""
    charts = {}

    # Generate a few test plots
    plot_generators = [
        lambda: plt.plot([1, 2, 3, 4], [1, 4, 2, 3]),
        lambda: plt.bar(['A', 'B', 'C'], [1, 2, 3]),
        lambda: plt.scatter(np.random.rand(20), np.random.rand(20))
    ]

    for i, generator in enumerate(plot_generators):
        plt.figure(figsize=(8, 6))
        generator()
        plt.title(f"Test Chart {i+1}")

        # Convert to base64
        buf = io.BytesIO()
        plt.savefig(buf, format='png', dpi=150, bbox_inches='tight')
        buf.seek(0)
        img_base64 = base64.b64encode(buf.read()).decode('utf-8')
        charts[f"chartKey_{i}"] = [img_base64]
        plt.close()

    return charts

# MARK: - Error Handling

@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "detail": str(exc),
            "type": type(exc).__name__
        }
    )

# MARK: - Server Configuration

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="debug"
    )

"""
DEPLOYMENT NOTES:

1. Dependencies (requirements.txt):
   - fastapi
   - uvicorn
   - nbformat
   - nbconvert
   - matplotlib
   - numpy
   - python-multipart

2. Docker deployment:
   ```dockerfile
   FROM python:3.9
   WORKDIR /app
   COPY requirements.txt .
   RUN pip install -r requirements.txt
   COPY . .
   CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
   ```

3. Storage Options:
   - PostgreSQL for notebook metadata
   - S3/MinIO for notebook files
   - Redis for temporary chart caching
   
4. Security Considerations:
   - Add authentication/authorization
   - Validate and sandbox code execution
   - Rate limiting for code execution endpoints
   - Input validation for all uploads
"""
