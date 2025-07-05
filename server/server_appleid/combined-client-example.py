"""
Example client demonstrating both notebook processing and point cloud search
in the combined Flask application.
"""

import requests
import json
from pathlib import Path

class CombinedAPIClient:
    def __init__(self, base_url="http://localhost:8000"):
        self.base_url = base_url
        self.token = None
        self.headers = {"Content-Type": "application/json"}
    
    # ========== Authentication Methods ==========
    
    def register(self, username, email, password):
        """Register a new user."""
        response = requests.post(
            f"{self.base_url}/api/auth/register",
            json={"username": username, "email": email, "password": password}
        )
        
        if response.status_code == 201:
            data = response.json()
            self.token = data["token"]
            self._update_auth_header()
            print(f"✓ Registered as {username}")
            return data
        else:
            print(f"✗ Registration failed: {response.json().get('error')}")
            return None
    
    def login(self, username, password):
        """Login with existing credentials."""
        response = requests.post(
            f"{self.base_url}/api/auth/login",
            json={"username": username, "password": password}
        )
        
        if response.status_code == 200:
            data = response.json()
            self.token = data["token"]
            self._update_auth_header()
            print(f"✓ Logged in as {username}")
            return data
        else:
            print(f"✗ Login failed: {response.json().get('error')}")
            return None
    
    def _update_auth_header(self):
        """Update headers with authentication token."""
        if self.token:
            self.headers["Authorization"] = f"Bearer {self.token}"
    
    # ========== Notebook Processing Methods ==========
    
    def process_notebook(self, notebook_path):
        """Process a notebook and extract outputs (no auth required)."""
        with open(notebook_path, 'rb') as f:
            files = {'notebook': f}
            
            # Remove Content-Type for multipart
            headers = {k: v for k, v in self.headers.items() if k != "Content-Type"}
            
            response = requests.post(
                f"{self.base_url}/process_notebook",
                files=files,
                headers=headers if self.token else None
            )
        
        if response.status_code == 200:
            data = response.json()
            print(f"\n✓ Notebook processed successfully")
            print(f"  - Total outputs: {data['total_outputs']}")
            print(f"  - Charts found: {data['total_charts']}")
            print(f"  - Validation: {'Passed' if data['validation']['success'] else 'Failed'}")
            return data
        else:
            print(f"✗ Processing failed: {response.json().get('error')}")
            return None
    
    def convert_notebook(self, notebook_path, notebook_name):
        """Convert notebook and extract charts."""
        with open(notebook_path, 'rb') as f:
            files = {'file': f}
            
            headers = {k: v for k, v in self.headers.items() if k != "Content-Type"}
            
            response = requests.post(
                f"{self.base_url}/convert/{notebook_name}",
                files=files,
                headers=headers if self.token else None
            )
        
        if response.status_code == 200:
            print(f"✓ Notebook converted successfully")
            return response.json()
        else:
            print(f"✗ Conversion failed: {response.json().get('error')}")
            return None
    
    def list_notebooks(self):
        """List notebooks (user's if authenticated, all if not)."""
        response = requests.get(
            f"{self.base_url}/notebooks",
            headers=self.headers if self.token else None
        )
        
        if response.status_code == 200:
            notebooks = response.json()
            if notebooks and isinstance(notebooks[0], dict):
                # Authenticated response
                print(f"\n✓ Your notebooks ({len(notebooks)} total):")
                for nb in notebooks:
                    print(f"  - {nb['filename']} (ID: {nb['id']})")
            else:
                # Unauthenticated response
                print(f"\n✓ Available notebooks ({len(notebooks)} total):")
                for nb in notebooks:
                    print(f"  - {nb}")
            return notebooks
        else:
            print(f"✗ Failed to list notebooks")
            return None
    
    # ========== Point Cloud Methods (Auth Required) ==========
    
    def upload_point_cloud(self, file_path):
        """Upload a point cloud file."""
        if not self.token:
            print("✗ Authentication required for point cloud operations")
            return None
        
        with open(file_path, 'rb') as f:
            files = {'file': f}
            headers = {k: v for k, v in self.headers.items() if k != "Content-Type"}
            
            response = requests.post(
                f"{self.base_url}/api/point-clouds/upload",
                files=files,
                headers=headers
            )
        
        if response.status_code == 201:
            data = response.json()
            print(f"✓ Uploaded {Path(file_path).name} (ID: {data['id']}, Points: {data['num_points']:,})")
            return data
        else:
            print(f"✗ Upload failed: {response.json().get('error')}")
            return None
    
    def search_point_clouds(self, query_file, top_k=5):
        """Search for similar point clouds."""
        if not self.token:
            print("✗ Authentication required for point cloud operations")
            return None
        
        with open(query_file, 'rb') as f:
            files = {'file': f}
            headers = {k: v for k, v in self.headers.items() if k != "Content-Type"}
            
            response = requests.post(
                f"{self.base_url}/api/point-clouds/search",
                files=files,
                headers=headers,
                params={'top_k': top_k}
            )
        
        if response.status_code == 200:
            data = response.json()
            print(f"\n✓ Search results ({len(data['results'])} matches):")
            for i, result in enumerate(data['results'], 1):
                print(f"  {i}. {result['filename']} - Similarity: {result['similarity_score']:.3f}")
            return data
        else:
            print(f"✗ Search failed: {response.json().get('error')}")
            return None
    
    def get_profile(self):
        """Get user profile with statistics."""
        if not self.token:
            print("✗ Authentication required")
            return None
        
        response = requests.get(
            f"{self.base_url}/api/auth/profile",
            headers=self.headers
        )
        
        if response.status_code == 200:
            data = response.json()
            user = data['user']
            print(f"\n✓ User Profile:")
            print(f"  - Username: {user['username']}")
            print(f"  - Email: {user['email']}")
            print(f"  - Point Clouds: {user['point_cloud_count']}")
            print(f"  - Notebooks: {user['notebook_count']}")
            return data
        else:
            print(f"✗ Failed to get profile")
            return None
    
    # ========== Health Check ==========
    
    def check_health(self):
        """Check API health status."""
        response = requests.get(f"{self.base_url}/health")
        
        if response.status_code == 200:
            data = response.json()
            print(f"\n✓ API Status: {data['status']}")
            print("  Services:")
            for service, status in data['services'].items():
                print(f"    - {service}: {status}")
            return data
        else:
            print("✗ Health check failed")
            return None


# Example usage
if __name__ == "__main__":
    # Initialize client
    client = CombinedAPIClient()
    
    # Check API health
    print("=== API Health Check ===")
    client.check_health()
    
    # Example 1: Process notebook without authentication
    print("\n=== Notebook Processing (No Auth) ===")
    # client.process_notebook("example.ipynb")
    # client.list_notebooks()
    
    # Example 2: Register/login and use authenticated features
    print("\n=== Authentication ===")
    # Register new user (or login if already exists)
    if not client.register("demo_user", "demo@example.com", "demo123"):
        client.login("demo_user", "demo123")
    
    # Get profile
    client.get_profile()
    
    # Example 3: Process notebook with authentication (saves to DB)
    print("\n=== Notebook Processing (With Auth) ===")
    # client.convert_notebook("example.ipynb", "my_analysis")
    # client.list_notebooks()
    
    # Example 4: Point cloud operations (requires auth)
    print("\n=== Point Cloud Operations ===")
    # Upload point clouds
    # client.upload_point_cloud("sample1.ply")
    # client.upload_point_cloud("sample2.pcd")
    
    # Search for similar point clouds
    # client.search_point_clouds("query.ply", top_k=10)
    
    print("\n✓ Demo completed!")
    
    # Create sample point cloud file for testing
    print("\n=== Creating Test Files ===")
    
    # Create a simple XYZ point cloud
    with open("test_cloud.xyz", "w") as f:
        f.write("0.0 0.0 0.0\n")
        f.write("1.0 0.0 0.0\n")
        f.write("0.0 1.0 0.0\n")
        f.write("0.0 0.0 1.0\n")
        f.write("0.5 0.5 0.5\n")
    print("✓ Created test_cloud.xyz")
    
    # Create a simple notebook
    notebook_content = {
        "cells": [
            {
                "cell_type": "code",
                "execution_count": 1,
                "metadata": {},
                "outputs": [],
                "source": "import matplotlib.pyplot as plt\nimport numpy as np\n\nx = np.linspace(0, 10, 100)\ny = np.sin(x)\n\nplt.plot(x, y)\nplt.title('Sine Wave')\nplt.show()"
            }
        ],
        "metadata": {
            "kernelspec": {
                "display_name": "Python 3",
                "language": "python",
                "name": "python3"
            }
        },
        "nbformat": 4,
        "nbformat_minor": 4
    }
    
    with open("test_notebook.ipynb", "w") as f:
        json.dump(notebook_content, f, indent=2)
    print("✓ Created test_notebook.ipynb")
    
    print("\nYou can now test with:")
    print("  - client.upload_point_cloud('test_cloud.xyz')")
    print("  - client.process_notebook('test_notebook.ipynb')")