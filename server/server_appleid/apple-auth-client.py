"""
Enhanced API client with Apple ID authentication support
"""

import requests
import webbrowser
import json
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading
import time
from urllib.parse import parse_qs, urlparse

class AppleAuthCallbackHandler(BaseHTTPRequestHandler):
    """Handler for Apple auth callback in local development"""
    
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        # Parse form data
        params = parse_qs(post_data.decode('utf-8'))
        
        # Extract token from the form data
        if 'id_token' in params:
            # Send to main app
            self.server.auth_data = params
            
            # Send response
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            
            response = """
            <html>
            <body>
            <script>
                window.close();
            </script>
            <p>Authentication successful! You can close this window.</p>
            </body>
            </html>
            """
            self.wfile.write(response.encode())
    
    def log_message(self, format, *args):
        # Suppress default logging
        pass

class EnhancedAPIClient:
    def __init__(self, base_url="http://localhost:8000"):
        self.base_url = base_url
        self.token = None
        self.headers = {"Content-Type": "application/json"}
    
    # ========== Apple ID Authentication ==========
    
    def login_with_apple(self):
        """Initiate Apple ID login flow"""
        print("🍎 Starting Apple ID authentication...")
        
        # Get Apple auth URL
        response = requests.get(f"{self.base_url}/api/auth/apple/login")
        
        if response.status_code != 200:
            print("✗ Failed to get Apple auth URL")
            return None
        
        auth_url = response.json()['auth_url']
        
        # For development, we'll open in browser and handle callback
        print("📱 Opening Apple sign-in page in your browser...")
        print("   Please sign in with your Apple ID")
        
        # Open browser
        webbrowser.open(auth_url)
        
        # In production, you'd handle the callback differently
        # For demo purposes, we'll just show the URL
        print(f"\n🔗 Auth URL: {auth_url}")
        print("\n⚠️  Note: In production, the callback will be handled by your server")
        print("   For local testing, you'll need to implement a callback handler\n")
        
        return True
    
    def verify_apple_token(self, oauth_token):
        """Verify an OAuth token received from Apple login"""
        response = requests.post(
            f"{self.base_url}/api/auth/login",
            json={"oauth_token": oauth_token}
        )
        
        if response.status_code == 200:
            data = response.json()
            self.token = oauth_token
            self._update_auth_header()
            print(f"✓ Apple ID login successful")
            print(f"  User: {data['user']['full_name'] or data['user']['username']}")
            print(f"  Email: {data['user']['email']}")
            return data
        else:
            print(f"✗ Token verification failed")
            return None
    
    # ========== Traditional Authentication ==========
    
    def register(self, username, email, password):
        """Register with username/password"""
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
        """Login with username/password"""
        response = requests.post(
            f"{self.base_url}/api/auth/login",
            json={"username": username, "password": password}
        )
        
        if response.status_code == 200:
            data = response.json()
            self.token = data["token"]
            self._update_auth_header()
            user = data['user']
            print(f"✓ Logged in as {user['username']}")
            if user.get('oauth_provider'):
                print(f"  (Linked with {user['oauth_provider']})")
            return data
        else:
            print(f"✗ Login failed: {response.json().get('error')}")
            return None
    
    def _update_auth_header(self):
        """Update headers with authentication token."""
        if self.token:
            self.headers["Authorization"] = f"Bearer {self.token}"
    
    # ========== Profile Management ==========
    
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
            if user.get('full_name'):
                print(f"  - Full Name: {user['full_name']}")
            print(f"  - Point Clouds: {user['point_cloud_count']}")
            print(f"  - Notebooks: {user['notebook_count']}")
            print(f"  - Member Since: {user['created_at'][:10]}")
            return data
        else:
            print(f"✗ Failed to get profile")
            return None
    
    # ========== Interactive Demo ==========
    
    def interactive_demo(self):
        """Run an interactive demo"""
        print("\n" + "="*50)
        print("🚀 Enhanced API Client Demo")
        print("="*50)
        
        # Check health
        print("\n📊 Checking API health...")
        response = requests.get(f"{self.base_url}/health")
        if response.status_code == 200:
            data = response.json()
            print(f"✓ API Status: {data['status']}")
            for service, status in data['services'].items():
                print(f"  - {service}: {status}")
        
        # Authentication options
        print("\n🔐 Authentication Options:")
        print("1. Sign in with Apple ID")
        print("2. Login with username/password")
        print("3. Register new account")
        print("4. Skip authentication")
        
        choice = input("\nChoose an option (1-4): ").strip()
        
        if choice == '1':
            self.login_with_apple()
            print("\n💡 After completing Apple sign-in, run:")
            print("   client.verify_apple_token('YOUR_TOKEN_HERE')")
            
        elif choice == '2':
            username = input("Username or email: ")
            password = input("Password: ")
            self.login(username, password)
            
        elif choice == '3':
            username = input("Choose username: ")
            email = input("Email address: ")
            password = input("Choose password: ")
            self.register(username, email, password)
            
        elif choice == '4':
            print("⚠️  Skipping authentication - some features won't be available")
        
        # Show available operations
        if self.token:
            print("\n✨ Authenticated! Available operations:")
            print("1. View profile")
            print("2. Upload point cloud")
            print("3. Search point clouds")
            print("4. Process notebook")
            print("5. List notebooks")
            
            op = input("\nChoose operation (1-5) or 'q' to quit: ").strip()
            
            if op == '1':
                self.get_profile()
            elif op == '2':
                print("\n📁 Creating sample point cloud...")
                self._create_sample_files()
                # Upload point cloud example
                print("client.upload_point_cloud('test_cloud.xyz')")
            elif op == '3':
                print("\n🔍 Search example:")
                print("client.search_point_clouds('test_cloud.xyz', top_k=5)")
            elif op == '4':
                print("\n📓 Process notebook example:")
                print("client.process_notebook('test_notebook.ipynb')")
            elif op == '5':
                print("\n📚 List notebooks example:")
                print("client.list_notebooks()")
        else:
            print("\n📓 Available without authentication:")
            print("- Process notebooks")
            print("- List public notebooks")
            print("\nExample: client.process_notebook('notebook.ipynb')")
    
    def _create_sample_files(self):
        """Create sample files for testing"""
        # Sample point cloud
        with open("test_cloud.xyz", "w") as f:
            f.write("0.0 0.0 0.0\n1.0 0.0 0.0\n0.0 1.0 0.0\n0.0 0.0 1.0\n")
        print("✓ Created test_cloud.xyz")
        
        # Sample notebook
        notebook = {
            "cells": [{
                "cell_type": "code",
                "source": "print('Hello from notebook!')"
            }],
            "metadata": {},
            "nbformat": 4,
            "nbformat_minor": 4
        }
        with open("test_notebook.ipynb", "w") as f:
            json.dump(notebook, f)
        print("✓ Created test_notebook.ipynb")
    
    # ========== Notebook Operations ==========
    
    def process_notebook(self, notebook_path):
        """Process a notebook (works with or without auth)"""
        with open(notebook_path, 'rb') as f:
            files = {'notebook': f}
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
            return data
        else:
            print(f"✗ Processing failed: {response.json().get('error')}")
            return None
    
    # ========== Point Cloud Operations ==========
    
    def upload_point_cloud(self, file_path):
        """Upload a point cloud file (requires auth)"""
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
            print(f"✓ Uploaded {Path(file_path).name}")
            print(f"  ID: {data['id']}")
            print(f"  Points: {data['num_points']:,}")
            return data
        else:
            print(f"✗ Upload failed: {response.json().get('error')}")
            return None
    
    def search_point_clouds(self, query_file, top_k=5):
        """Search for similar point clouds (requires auth)"""
        if not self.token:
            print("✗ Authentication required")
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
            print(f"\n✓ Found {len(data['results'])} similar point clouds:")
            for i, result in enumerate(data['results'], 1):
                print(f"  {i}. {result['filename']}")
                print(f"     Similarity: {result['similarity_score']:.3f}")
                print(f"     Points: {result['num_points']:,}")
            return data
        else:
            print(f"✗ Search failed: {response.json().get('error')}")
            return None


# Example usage
if __name__ == "__main__":
    # Create client
    client = EnhancedAPIClient()
    
    # Run interactive demo
    client.interactive_demo()
    
    print("\n📚 Quick Reference:")
    print("- Apple login: client.login_with_apple()")
    print("- Traditional login: client.login('username', 'password')")
    print("- Register: client.register('username', 'email', 'password')")
    print("- Profile: client.get_profile()")
    print("- Upload: client.upload_point_cloud('file.ply')")
    print("- Search: client.search_point_clouds('query.ply')")
    print("- Process: client.process_notebook('notebook.ipynb')")
    
    print("\n💡 For Apple sign-in integration in your app:")
    print("   See: http://localhost:8000/apple-login-demo")