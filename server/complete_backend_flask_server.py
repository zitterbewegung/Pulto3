from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import nbformat
import nbval
import base64
import json
import os
import tempfile
import subprocess
import re
from io import StringIO, BytesIO
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt
import numpy as np
from werkzeug.utils import secure_filename
# Use a pipeline as a high-level helper
from transformers import pipeline

app = Flask(__name__)
CORS(app)

# Configuration
UPLOAD_FOLDER = '/tmp/notebooks'
ALLOWED_EXTENSIONS = {'ipynb'}


pipe = pipeline("video-classification", model="facebook/vjepa2-vitl-fpc64-256")

# Ensure upload directory exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def allowed_file(filename):
    """Check if file extension is allowed"""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def extract_outputs_from_notebook(notebook_path):
    """Extract all outputs including text, charts, and data from a notebook"""
    with open(notebook_path, 'r', encoding='utf-8') as f:
        nb = nbformat.read(f, as_version=4)
    
    outputs = []
    
    for cell_idx, cell in enumerate(nb.cells):
        if cell.cell_type == 'code' and hasattr(cell, 'outputs'):
            for output_idx, output in enumerate(cell.outputs):
                output_data = {
                    'cell_index': cell_idx,
                    'output_index': output_idx,
                    'type': output.output_type
                }
                
                if output.output_type == 'stream':
                    output_data['text'] = output.text
                    output_data['stream'] = output.name
                
                elif output.output_type == 'display_data' or output.output_type == 'execute_result':
                    data = output.data
                    
                    # Handle different data types
                    if 'text/plain' in data:
                        output_data['text'] = data['text/plain']
                    
                    if 'image/png' in data:
                        output_data['image_png'] = data['image/png']
                        output_data['image_type'] = 'png'
                    
                    if 'image/jpeg' in data:
                        output_data['image_jpeg'] = data['image/jpeg']
                        output_data['image_type'] = 'jpeg'
                    
                    if 'application/json' in data:
                        output_data['json_data'] = data['application/json']
                    
                    if 'text/html' in data:
                        output_data['html'] = data['text/html']
                        # Try to extract data from pandas DataFrame HTML
                        if 'dataframe' in data['text/html'].lower():
                            output_data['is_dataframe'] = True
                
                elif output.output_type == 'error':
                    output_data['error'] = {
                        'name': output.ename,
                        'value': output.evalue,
                        'traceback': output.traceback
                    }
                
                outputs.append(output_data)
    
    return outputs

def validate_notebook(notebook_path):
    """Run nbval to validate the notebook"""
    try:
        result = subprocess.run(
            ['pytest', '--nbval', notebook_path],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        return {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'return_code': result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            'success': False,
            'error': 'Validation timeout'
        }
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }

def generate_chart_images_from_notebook(notebook_path):
    """Generate chart images from notebook cells containing matplotlib code"""
    with open(notebook_path, 'r', encoding='utf-8') as f:
        nb = nbformat.read(f, as_version=4)
    
    chart_images = {}
    
    for cell_idx, cell in enumerate(nb.cells):
        if cell.cell_type == 'code' and cell.source:
            # Look for matplotlib/plotting code
            source_code = ''.join(cell.source) if isinstance(cell.source, list) else cell.source
            
            if any(keyword in source_code.lower() for keyword in ['plt.', 'matplotlib', 'plot(', 'scatter(', 'bar(']):
                try:
                    # Create a safe execution environment
                    exec_globals = {
                        '__builtins__': __builtins__,
                        'plt': plt,
                        'np': np,
                        'numpy': np,
                        'matplotlib': matplotlib
                    }
                    
                    # Execute the cell
                    exec(source_code, exec_globals)
                    
                    # Save the current figure to base64
                    buffer = BytesIO()
                    plt.savefig(buffer, format='png', dpi=150, bbox_inches='tight')
                    buffer.seek(0)
                    
                    image_base64 = base64.b64encode(buffer.read()).decode('utf-8')
                    chart_key = f"chartKey_{cell_idx:03d}"
                    chart_images[chart_key] = [image_base64]  # Swift expects array of images
                    
                    # Clear the figure
                    plt.clf()
                    plt.close('all')
                    
                except Exception as e:
                    print(f"Error executing cell {cell_idx}: {str(e)}")
                    continue
    
    return chart_images

def update_notebook_spatial_metadata(notebook_path, spatial_data, cell_index=None):
    """Update spatial metadata in notebook"""
    with open(notebook_path, 'r', encoding='utf-8') as f:
        nb = nbformat.read(f, as_version=4)
    
    # Update specific cell or all cells
    if cell_index is not None:
        if cell_index < len(nb.cells):
            if 'metadata' not in nb.cells[cell_index]:
                nb.cells[cell_index]['metadata'] = {}
            nb.cells[cell_index]['metadata']['spatial'] = spatial_data
    else:
        # Update all cells
        for cell in nb.cells:
            if 'metadata' not in cell:
                cell['metadata'] = {}
            cell['metadata']['spatial'] = spatial_data
    
    # Save updated notebook
    with open(notebook_path, 'w', encoding='utf-8') as f:
        nbformat.write(nb, f)
    
    return nb

# MARK: - API Endpoints

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'service': 'notebook-processor'})

@app.route('/convert/<notebook_name>', methods=['POST'])
def convert_notebook(notebook_name):
    """Convert notebook and extract charts with spatial positioning"""
    try:
        if 'file' not in request.files:
            return jsonify({'error': 'No file provided'}), 400
        
        file = request.files['file']
        
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        if file and allowed_file(file.filename):
            # Secure the filename and save temporarily
            filename = secure_filename(file.filename)
            temp_path = os.path.join(UPLOAD_FOLDER, filename)
            file.save(temp_path)
            
            try:
                # Parse the uploaded notebook to check if it has nbformat structure
                with open(temp_path, 'r', encoding='utf-8') as f:
                    notebook_content = json.load(f)
                
                # If it has nbformat, return the updated notebook with chart positions
                if 'nbformat' in notebook_content:
                    # Process any chart generation or updates here
                    chart_images = generate_chart_images_from_notebook(temp_path)
                    
                    # Add chart positions to metadata if not present
                    if 'metadata' not in notebook_content:
                        notebook_content['metadata'] = {}
                    
                    # Return the updated notebook
                    return jsonify(notebook_content)
                    
                else:
                    # Generate chart images and return them
                    chart_images = generate_chart_images_from_notebook(temp_path)
                    
                    if chart_images:
                        return jsonify(chart_images)
                    else:
                        return jsonify({'message': 'No charts found in notebook'}), 200
                        
            finally:
                # Clean up temporary file
                if os.path.exists(temp_path):
                    os.unlink(temp_path)
        
        return jsonify({'error': 'Invalid file type'}), 400
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/process_notebook', methods=['POST'])
def process_notebook():
    """Process a Jupyter notebook and return all outputs"""
    try:
        if 'notebook' not in request.files:
            return jsonify({'error': 'No notebook file provided'}), 400
        
        file = request.files['notebook']
        
        # Save the uploaded file temporarily
        with tempfile.NamedTemporaryFile(mode='wb', suffix='.ipynb', delete=False) as tmp:
            file.save(tmp.name)
            tmp_path = tmp.name
        
        try:
            # Validate notebook with nbval
            validation_result = validate_notebook(tmp_path)
            
            # Extract outputs
            outputs = extract_outputs_from_notebook(tmp_path)
            
            # Prepare response
            response = {
                'validation': validation_result,
                'outputs': outputs,
                'total_outputs': len(outputs)
            }
            
            # Extract chart data for Swift
            charts = []
            for output in outputs:
                if output.get('image_png') or output.get('image_jpeg'):
                    chart = {
                        'cell_index': output['cell_index'],
                        'output_index': output['output_index'],
                        'image_data': output.get('image_png') or output.get('image_jpeg'),
                        'image_type': output.get('image_type', 'png')
                    }
                    charts.append(chart)
            
            response['charts'] = charts
            response['total_charts'] = len(charts)
            
            return jsonify(response)
            
        finally:
            # Clean up
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/notebooks', methods=['GET'])
def list_notebooks():
    """List all available notebooks"""
    try:
        notebooks = []
        for filename in os.listdir(UPLOAD_FOLDER):
            if filename.endswith('.ipynb'):
                notebooks.append(filename)
        return jsonify(notebooks)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/notebooks/<notebook_name>/cells/<int:cell_index>/spatial', methods=['PUT'])
def update_cell_spatial_metadata(notebook_name, cell_index):
    """Update spatial metadata for a specific cell"""
    try:
        spatial_data = request.get_json()
        
        if not spatial_data:
            return jsonify({'error': 'No spatial data provided'}), 400
        
        notebook_path = os.path.join(UPLOAD_FOLDER, secure_filename(notebook_name))
        
        if not os.path.exists(notebook_path):
            return jsonify({'error': 'Notebook not found'}), 404
        
        # Update the notebook
        updated_nb = update_notebook_spatial_metadata(notebook_path, spatial_data, cell_index)
        
        return jsonify({
            'message': f'Spatial metadata updated for cell {cell_index}',
            'spatial_data': spatial_data
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/notebooks/<notebook_name>/cells/spatial', methods=['PUT'])
def update_all_cells_spatial_metadata(notebook_name):
    """Update spatial metadata for all cells in a notebook"""
    try:
        spatial_data = request.get_json()
        
        if not spatial_data:
            return jsonify({'error': 'No spatial data provided'}), 400
        
        notebook_path = os.path.join(UPLOAD_FOLDER, secure_filename(notebook_name))
        
        if not os.path.exists(notebook_path):
            return jsonify({'error': 'Notebook not found'}), 404
        
        # Update all cells in the notebook
        updated_nb = update_notebook_spatial_metadata(notebook_path, spatial_data)
        
        return jsonify({
            'message': 'Spatial metadata updated for all cells',
            'spatial_data': spatial_data,
            'total_cells': len(updated_nb.cells)
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/notebooks/<notebook_name>', methods=['GET'])
def get_notebook(notebook_name):
    """Get a specific notebook"""
    try:
        notebook_path = os.path.join(UPLOAD_FOLDER, secure_filename(notebook_name))
        
        if not os.path.exists(notebook_path):
            return jsonify({'error': 'Notebook not found'}), 404
        
        with open(notebook_path, 'r', encoding='utf-8') as f:
            notebook_content = json.load(f)
        
        return jsonify(notebook_content)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/notebooks/<notebook_name>/download', methods=['GET'])
def download_notebook(notebook_name):
    """Download a notebook file"""
    try:
        notebook_path = os.path.join(UPLOAD_FOLDER, secure_filename(notebook_name))
        
        if not os.path.exists(notebook_path):
            return jsonify({'error': 'Notebook not found'}), 404
        
        return send_file(notebook_path, as_attachment=True, download_name=notebook_name)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

@app.errorhandler(413)
def too_large(error):
    return jsonify({'error': 'File too large'}), 413

if __name__ == '__main__':
    # For development
    app.run(host='0.0.0.0', port=8000, debug=True)
else:
    # For production (gunicorn)
    app.run(host='0.0.0.0', port=5000, debug=False)
