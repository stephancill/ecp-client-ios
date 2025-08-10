# Security Setup Guide

## ⚠️ IMPORTANT: Info.plist Configuration

The `Info.plist` file contains sensitive configuration data and should **NEVER** be committed to git.

### Setup Instructions:

1. **Copy the template file:**
   ```bash
   cp ecp-client/Info.plist.template ecp-client/Info.plist
   ```

2. **Configure your Pinata credentials:**
   - Get your Pinata JWT token from [Pinata Dashboard](https://app.pinata.cloud/)
   - Replace `YOUR_PINATA_JWT_TOKEN_HERE` with your actual JWT token
   - Replace `YOUR_PINATA_GATEWAY_URL_HERE` with your gateway URL

3. **Never commit Info.plist:**
   - The file is already in `.gitignore`
   - If you accidentally commit it, immediately revoke and regenerate your JWT token

### Security Notes:

- **JWT tokens are sensitive credentials** - treat them like passwords
- **Never share JWT tokens** in code, logs, or public repositories
- **Revoke compromised tokens** immediately in your Pinata dashboard
- **Use environment variables** for production deployments

### Required Configuration:

- `API_BASE_URL`: Backend API endpoint
- `PINATA_JWT`: Your Pinata JWT token for image uploads
- `PINATA_GATEWAY_URL`: Your Pinata gateway URL for image retrieval

## Emergency Token Revocation

If your JWT token has been exposed:

1. **Immediately revoke the token** in your Pinata dashboard
2. **Generate a new JWT token**
3. **Update your local Info.plist** with the new token
4. **Check git history** to ensure the old token is removed
