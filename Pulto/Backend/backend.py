from flask import Flask, request, jsonify
from flask_cors import CORS
import nbformat
import nbval
import base64
import json
import os
import tempfile
import subprocess
import re
from io import StringIO

app = Flask(__name__)
CORS(app)

def extract_outputs_from_notebook(notebook_path):
    """Extract all outputs including text, charts, and data from a notebook"""
    with open(notebook_path, 'r') as f:
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
            text=True
        )
        
        return {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'return_code': result.returncode
        }
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }

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
        
        # Validate notebook with nbval
        validation_result = validate_notebook(tmp_path)
        
        # Extract outputs
        outputs = extract_outputs_from_notebook(tmp_path)
        
        # Clean up
        os.unlink(tmp_path)
        
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
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)