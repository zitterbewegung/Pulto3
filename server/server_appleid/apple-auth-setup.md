# Apple ID Authentication Setup Guide

## Prerequisites

1. **Apple Developer Account** ($99/year)
   - Sign up at [developer.apple.com](https://developer.apple.com)
   - Required for Sign in with Apple

2. **App ID and Service ID**
   - You'll need to create these in your Apple Developer account

## Step 1: Configure Apple Developer Account

### 1.1 Create an App ID

1. Go to [Apple Developer](https://developer.apple.com/account/resources/identifiers/list)
2. Click the **+** button to add a new identifier
3. Select **App IDs** and click **Continue**
4. Select **App** and click **Continue**
5. Fill in:
   - **Description**: Your App Name
   - **Bundle ID**: `com.yourcompany.yourapp` (reverse domain style)
6. Under **Capabilities**, check **Sign In with Apple**
7. Click **Continue** and then **Register**

### 1.2 Create a Service ID (for Web)

1. In the same Identifiers section, click **+** again
2. Select **Services IDs** and click **Continue**
3. Fill in:
   - **Description**: Your App Name Web
   - **Identifier**: `com.yourcompany.yourapp.web`
4. Click **Continue** and **Register**
5. Click on your new Service ID from the list
6. Check **Sign In with Apple**
7. Click **Configure** next to Sign In with Apple
8. Set:
   - **Primary App ID**: Select the App ID you created
   - **Domains and Subdomains**: Add your domain (e.g., `yourdomain.com`)
   - **Return URLs**: Add your callback URL (e.g., `https://yourdomain.com/api/auth/apple/callback`)
   - For development, add: `http://localhost:8000/api/auth/apple/callback`
9. Click **Save**

### 1.3 Create a Key

1. Go to **Keys** section in Apple Developer
2. Click **+** to create a new key
3. Fill in:
   - **Key Name**: Your App Auth Key
   - Check **Sign in with Apple**
4. Click **Configure** next to Sign in with Apple
5. Select your Primary App ID
6. Click **Save** and then **Continue**
7. Click **Register**
8. **Download the key file** (you can only download it once!)
9. Note the **Key ID** shown on the screen

### 1.4 Get Your Team ID

1. Go to **Membership** section in Apple Developer
2. Find your **Team ID** (10-character string)

## Step 2: Configure Your Flask App

### 2.1 Environment Variables

Create or update your `.env` file:

```env
# Existing variables...

# Apple ID Authentication
APPLE_CLIENT_ID=com.yourcompany.yourapp.web  # Your Service ID
APPLE_TEAM_ID=XXXXXXXXXX  # Your 10-character Team ID
APPLE_KEY_ID=XXXXXXXXXX   # Your Key ID
APPLE_REDIRECT_URI=http://localhost:8000/api/auth/apple/callback

# Your private key content (base64 encoded)
# Convert your .p8 file to base64: base64 -i AuthKey_XXXXXX.p8
APPLE_PRIVATE_KEY=LS0tLS1CRUdJTi...
```

### 2.2 Convert Your Private Key

Convert your downloaded `.p8` key file to base64:

```bash
# On macOS/Linux
base64 -i AuthKey_XXXXXXXXXX.p8

# On Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8"))
```

Copy the entire output and set it as `APPLE_PRIVATE_KEY` in your `.env` file.

### 2.3 Update Database

Run migration to add new OAuth fields:

```python
# In Python shell
from app import app, db
with app.app_context():
    db.drop_all()  # WARNING: This will delete all data!
    db.create_all()

# Or create a migration script if you have existing data
```

### 2.4 Install Additional Dependencies

```bash
pip install PyJWT[crypto] cryptography requests
```

Updated requirements.txt additions:
```
PyJWT[crypto]==2.8.0
cryptography==41.0.7
requests==2.31.0
```

## Step 3: Testing

### 3.1 Test Locally

1. Start your Flask app:
   ```bash
   python app.py
   ```

2. Visit: `http://localhost:8000/apple-login-demo`

3. Click "Sign in with Apple"

4. You'll be redirected to Apple's login page

5. After authentication, you'll be redirected back to your app

### 3.2 Test the API Directly

```python
import requests

# Get Apple login URL
response = requests.get('http://localhost:8000/api/auth/apple/login')
print(response.json()['auth_url'])
# Open this URL in a browser
```

## Step 4: Production Setup

### 4.1 HTTPS Required

Apple requires HTTPS for production. Update your configuration:

```env
APPLE_REDIRECT_URI=https://yourdomain.com/api/auth/apple/callback
```

### 4.2 Update Apple Developer Settings

1. Go back to your Service ID configuration
2. Update domains and return URLs for production
3. Remove localhost URLs

### 4.3 Nginx Configuration

Add to your Nginx config:

```nginx
location /api/auth/apple/callback {
    proxy_pass http://localhost:8000/api/auth/apple/callback;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Important for POST requests from Apple
    proxy_method POST;
    proxy_set_body $request_body;
}
```

## Step 5: Frontend Integration

### 5.1 React Example

```jsx
import React, { useEffect } from 'react';

function AppleSignIn() {
  useEffect(() => {
    // Load Apple JS SDK
    const script = document.createElement('script');
    script.src = 'https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js';
    script.async = true;
    document.body.appendChild(script);

    // Configure Apple Sign In
    script.onload = () => {
      window.AppleID.auth.init({
        clientId: 'com.yourcompany.yourapp.web',
        scope: 'name email',
        redirectURI: 'https://yourdomain.com/api/auth/apple/callback',
        usePopup: true
      });
    };

    // Listen for success
    document.addEventListener('AppleIDSignInOnSuccess', (event) => {
      console.log('Success:', event.detail);
    });

    // Listen for failure  
    document.addEventListener('AppleIDSignInOnFailure', (event) => {
      console.error('Error:', event.detail);
    });

    // Cleanup
    return () => {
      document.body.removeChild(script);
    };
  }, []);

  return (
    <div 
      id="appleid-signin" 
      data-color="black" 
      data-border="false" 
      data-type="sign in"
    />
  );
}
```

### 5.2 Vue.js Example

```vue
<template>
  <div>
    <div 
      id="appleid-signin" 
      data-color="black" 
      data-border="false" 
      data-type="sign in"
    ></div>
  </div>
</template>

<script>
export default {
  mounted() {
    // Load Apple SDK
    const script = document.createElement('script');
    script.src = 'https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js';
    script.async = true;
    document.body.appendChild(script);

    // Configure when loaded
    script.onload = () => {
      window.AppleID.auth.init({
        clientId: 'com.yourcompany.yourapp.web',
        scope: 'name email',
        redirectURI: process.env.VUE_APP_APPLE_REDIRECT_URI,
        usePopup: true
      });
    };

    // Handle auth events
    this.setupEventListeners();
  },

  methods: {
    setupEventListeners() {
      document.addEventListener('AppleIDSignInOnSuccess', this.onSuccess);
      document.addEventListener('AppleIDSignInOnFailure', this.onFailure);
      
      // Listen for popup callback
      window.addEventListener('message', this.handleMessage);
    },

    handleMessage(event) {
      if (event.data.type === 'apple-auth-success') {
        // Store token and redirect
        localStorage.setItem('authToken', event.data.token);
        this.$router.push('/dashboard');
      }
    },

    onSuccess(event) {
      console.log('Apple Sign In Success:', event.detail);
    },

    onFailure(event) {
      console.error('Apple Sign In Failed:', event.detail);
    }
  },

  beforeDestroy() {
    document.removeEventListener('AppleIDSignInOnSuccess', this.onSuccess);
    document.removeEventListener('AppleIDSignInOnFailure', this.onFailure);
    window.removeEventListener('message', this.handleMessage);
  }
};
</script>
```

## Step 6: Customization Options

### 6.1 Button Styles

The Sign in with Apple button supports these configurations:

```html
<!-- Black button (recommended) -->
<div id="appleid-signin" 
     data-color="black" 
     data-border="false" 
     data-type="sign in"></div>

<!-- White button -->
<div id="appleid-signin" 
     data-color="white" 
     data-border="true" 
     data-type="sign in"></div>

<!-- Continue with Apple -->
<div id="appleid-signin" 
     data-color="black" 
     data-border="false" 
     data-type="continue"></div>
```

### 6.2 Custom Button

You can also create a custom button:

```javascript
async function signInWithApple() {
  try {
    const response = await fetch('/api/auth/apple/login');
    const data = await response.json();
    
    // Redirect to Apple's auth page
    window.location.href = data.auth_url;
  } catch (error) {
    console.error('Error:', error);
  }
}
```

## Troubleshooting

### Common Issues

1. **"invalid_client" error**
   - Verify your Service ID matches `APPLE_CLIENT_ID`
   - Check that Sign in with Apple is enabled for your Service ID
   - Ensure redirect URI matches exactly

2. **"invalid_request" error**
   - Check your private key is correctly formatted
   - Verify Team ID and Key ID are correct
   - Ensure private key hasn't expired

3. **Callback not working**
   - Ensure callback URL is registered in Apple Developer
   - Check that your server accepts POST requests
   - Verify HTTPS in production

4. **User info not received**
   - Apple only sends user info on first sign-in
   - Store user data when first received

### Debug Tips

1. Enable debug logging:
   ```python
   import logging
   logging.basicConfig(level=logging.DEBUG)
   ```

2. Test token generation:
   ```python
   from app import apple_auth
   try:
       secret = apple_auth.generate_client_secret()
       print("Client secret generated successfully")
   except Exception as e:
       print(f"Error: {e}")
   ```

3. Verify callback data:
   ```python
   @app.route('/api/auth/apple/callback', methods=['POST'])
   def apple_callback():
       print("Form data:", request.form)
       print("Headers:", request.headers)
       # ... rest of the handler
   ```

## Security Considerations

1. **Always verify tokens** - Never trust client-side data
2. **Use HTTPS in production** - Required by Apple
3. **Store minimal data** - Only store what you need
4. **Handle token expiration** - Implement token refresh
5. **Validate state parameter** - Prevent CSRF attacks

## Additional Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/sign_in_with_apple)
- [Sign in with Apple JS](https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_js)
- [REST API Documentation](https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api)