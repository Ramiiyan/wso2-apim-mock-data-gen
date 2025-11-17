# WSO2 APIM Mock Data Generator - Usage Guide

## Overview
This toolkit automates the generation of mock data for WSO2 API Manager (APIM), including APIs, applications, subscriptions, and application keys. It's designed to help developers and testers quickly populate a WSO2 APIM instance with test data.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Components Overview](#components-overview)
- [Usage Workflows](#usage-workflows)
- [Script Details](#script-details)
- [GitHub Actions Automation](#github-actions-automation)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools
- **bash/zsh shell** - All scripts are bash-based
- **curl** - For making REST API calls
- **jq** - For JSON parsing and manipulation
- **WSO2 API Manager** - A running WSO2 APIM instance (version 3.2.0+)

### Installation (macOS)
```bash
# Install jq if not already installed
brew install jq
```

### WSO2 APIM Setup
- A running WSO2 APIM instance
- Admin credentials
- API Manager endpoints accessible (default ports: 9443 for servlet, 8243 for gateway)
- If using MySQL database, ensure it's configured properly (see `deployment.toml`)

---

## Configuration

### 1. Environment Configuration (`config.env`)

The `config.env` file contains all necessary configuration parameters:

```env
# Admin Credentials
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="admin"

# Host Configuration
HOST="localhost"                # WSO2 APIM hostname
SERVLET_PORT="9443"             # Management console port
GATEWAY_PORT="8243"             # Gateway port

# OAuth Scopes
PUBLISHER_SCOPE="apim:api_create apim:api_view apim:api_publish apim:api_import_export"
SUBSCRIBER_SCOPE="apim:api_view apim:subscribe apim:api_key apim:app_manage apim:sub_manage apim:store_settings apim:sub_alert_manage apim:app_import_export"

# Application Settings
NUM_APPS=15                     # Number of test applications to create

# Key Manager
KEY_MANAGER_ID="Resident Key Manager"
```

**Note:** Client credentials (PUBLISHER_CLIENT_ID, SUBSCRIBER_CLIENT_ID, etc.) are automatically generated and appended to this file by the scripts.

### 2. API Configuration (`apis.csv`)

Define the APIs you want to create in the `apis.csv` file:

```csv
API_Name,Context,Endpoint
RandomUserAPI,randomuser,https://randomuser.me/api/
CatFactsAPI,catfacts,https://catfact.ninja/fact
JSONPlaceholderAPI,jsonplaceholder,https://jsonplaceholder.typicode.com/
BoredAPI,boredapi,https://www.boredapi.com/api/activity
```

**CSV Format:**
- **API_Name:** Name of the API
- **Context:** Context path for the API (will be prefixed with `/`)
- **Endpoint:** Backend endpoint URL

### 3. Database Configuration (Optional)

If using MySQL, configure it in `deployment.toml`:

```toml
[database.apim_db]
type = "mysql"
url = "jdbc:mysql://localhost:3306/WSO2_APIM_DB?useSSL=false"
username = "wso2carbon"
password = "wso2carbon"
driver = "com.mysql.cj.jdbc.Driver"

[database.shared_db]
type = "mysql"
url = "jdbc:mysql://localhost:3306/WSO2_SHARED_DB?useSSL=false"
username = "wso2carbon"
password = "wso2carbon"
driver = "com.mysql.cj.jdbc.Driver"
```

---

## Components Overview

### Core Scripts

| Script | Purpose | Dependencies |
|--------|---------|--------------|
| `api_creator.sh` | Creates APIs from CSV file | `config.env`, `apis.csv` |
| `api_publisher.sh` | Publishes all created APIs | `config.env` |
| `devportal_app_creator.sh` | Creates test applications | `config.env` |
| `app_keys_gen.sh` | Generates keys for applications | `config.env` |
| `subscribe_APIs.sh` | Subscribes applications to APIs | `config.env` |

### Configuration Files

| File | Purpose |
|------|---------|
| `config.env` | Environment variables and configuration |
| `apis.csv` | API definitions (name, context, endpoint) |
| `deployment.toml` | WSO2 APIM deployment configuration |

---

## Usage Workflows

### Workflow 1: Complete Setup (Recommended)

This workflow sets up everything from scratch - APIs, applications, keys, and subscriptions.

```bash
# Step 1: Ensure WSO2 APIM is running
# Check if APIM is accessible
curl -k https://localhost:9443/services/Version

# Step 2: Configure environment
# Edit config.env with your settings
vi config.env

# Step 3: Define your APIs
# Edit apis.csv with your API definitions
vi apis.csv

# Step 4: Create APIs
./api_creator.sh

# Step 5: Publish APIs
./api_publisher.sh

# Step 6: Create Applications
./devportal_app_creator.sh

# Step 7: Generate Application Keys
./app_keys_gen.sh

# Step 8: Subscribe Applications to APIs
./subscribe_APIs.sh
```

### Workflow 2: API Management Only

If you only need to create and publish APIs:

```bash
# Create APIs from CSV
./api_creator.sh

# Publish all created APIs
./api_publisher.sh
```

### Workflow 3: Application Management Only

If APIs already exist and you only need applications:

```bash
# Create applications
./devportal_app_creator.sh

# Generate keys for applications
./app_keys_gen.sh

# Subscribe to existing APIs
./subscribe_APIs.sh
```

### Workflow 4: Quick Reset and Rebuild

```bash
# 1. Clean up existing data (manual - via APIM console or database)
# 2. Run complete setup
./api_creator.sh && \
./api_publisher.sh && \
./devportal_app_creator.sh && \
./app_keys_gen.sh && \
./subscribe_APIs.sh
```

---

## Script Details

### 1. `api_creator.sh`

**Purpose:** Creates APIs in WSO2 APIM based on the definitions in `apis.csv`.

**Process:**
1. Registers a client application via DCR (Dynamic Client Registration)
2. Obtains an access token with publisher scopes
3. Reads API definitions from `apis.csv`
4. Creates each API with the following properties:
   - Version: 1.0.0
   - Lifecycle Status: CREATED
   - Response Caching: Enabled (300s timeout)
   - Transport: HTTP & HTTPS
   - Security: OAuth2
   - Throttling Policy: Unlimited
   - Single GET operation on `/` path

**Output:** 
- API IDs and creation status
- Updates `config.env` with publisher client credentials

**Usage:**
```bash
./api_creator.sh
```

### 2. `api_publisher.sh`

**Purpose:** Publishes all APIs that are in CREATED state.

**Process:**
1. Gets access token using stored publisher credentials
2. Fetches all APIs
3. Checks lifecycle state of each API
4. Publishes APIs that are in CREATED state
5. Skips APIs already published

**Output:** Status of each API publication

**Usage:**
```bash
./api_publisher.sh
```

### 3. `devportal_app_creator.sh`

**Purpose:** Creates multiple test applications in the Developer Portal.

**Process:**
1. Registers a client for devportal operations
2. Obtains access token with subscriber scopes
3. Creates applications based on `NUM_APPS` configuration
4. Each application is named with timestamp: `TestApp_{N}_{TIMESTAMP}`

**Application Properties:**
- Token Type: JWT
- Throttling Policy: Unlimited
- Subscription Scopes: Empty (default)

**Output:**
- Application IDs and creation status
- Updates `config.env` with subscriber client credentials

**Usage:**
```bash
./devportal_app_creator.sh
```

### 4. `app_keys_gen.sh`

**Purpose:** Generates OAuth keys for all applications.

**Process:**
1. Gets access token with subscriber scopes
2. Fetches all applications
3. For each application, generates:
   - PRODUCTION keys
   - SANDBOX keys

**Key Properties:**
- Grant Types: refresh_token, SAML2 bearer, password, client_credentials, IWA:NTLM, device code, JWT bearer
- Validity: 3600 seconds
- Scopes: am_application_scope, default
- Key Manager: Resident Key Manager (configurable)

**Output:** Keys generated for each application (both production and sandbox)

**Usage:**
```bash
./app_keys_gen.sh
```

### 5. `subscribe_APIs.sh`

**Purpose:** Subscribes all applications to all APIs.

**Process:**
1. Gets subscriber access token
2. Gets publisher access token
3. Fetches all applications
4. Fetches all APIs
5. Creates subscriptions for every app-API combination
6. Uses bulk subscription API endpoint

**Subscription Properties:**
- Throttling Policy: Unlimited
- Status: UNBLOCKED

**Output:** Subscription creation status

**Usage:**
```bash
./subscribe_APIs.sh
```

---

## GitHub Actions Automation

### Workflow: `wso2-apim-data-gen.yml`

This workflow automates the entire mock data generation process in CI/CD.

**Trigger:** Manual dispatch (`workflow_dispatch`)

**Inputs:**
- `host`: WSO2 APIM hostname (default: localhost)
- `admin_username`: Admin username (default: admin)
- `admin_password`: Admin password (default: admin)
- `num_apps`: Number of test applications (default: 15)
- `subscription`: Enable subscriptions (boolean, default: false)
- `U2_lvl`: Update level (optional)

**Process:**
1. Extracts APIM version from branch name (e.g., `wso2am-4.0.0`)
2. Downloads and extracts WSO2 APIM package
3. Configures MySQL database (if needed)
4. Starts WSO2 APIM instance
5. Waits for APIM to be ready
6. Runs all data generation scripts in sequence

**Usage:**
1. Go to GitHub Actions tab
2. Select "WSO2 APIM Dummy Data Generator" workflow
3. Click "Run workflow"
4. Fill in the parameters
5. Click "Run workflow" button

**Branch Naming Convention:**
- Branch should be named: `wso2am-X.Y.Z` (e.g., `wso2am-4.0.0`)
- Or simply: `X.Y.Z` (e.g., `4.0.0`)

---

## Troubleshooting

### Common Issues

#### 1. **"Failed to register client"**

**Cause:** WSO2 APIM not accessible or incorrect credentials

**Solution:**
```bash
# Verify APIM is running
curl -k https://localhost:9443/services/Version

# Check credentials in config.env
cat config.env | grep -E "ADMIN_USERNAME|ADMIN_PASSWORD"
```

#### 2. **"Failed to get access token"**

**Cause:** Invalid client credentials or scope issues

**Solution:**
- Verify client credentials in `config.env`
- Ensure scopes are correct
- Check APIM logs: `{APIM_HOME}/repository/logs/wso2carbon.log`

#### 3. **"No APIs found"**

**Cause:** APIs not created or not visible to the user

**Solution:**
```bash
# Re-run API creator
./api_creator.sh

# Check API creation in APIM Publisher console
# https://localhost:9443/publisher
```

#### 4. **"Invalid JSON response"**

**Cause:** APIM not ready, network issues, or API endpoint errors

**Solution:**
- Wait for APIM to fully start (can take 2-3 minutes)
- Check network connectivity
- Verify SSL certificate (scripts use `-k` flag to ignore SSL)

#### 5. **"jq: command not found"**

**Cause:** jq not installed

**Solution:**
```bash
# macOS
brew install jq

# Linux (Ubuntu/Debian)
sudo apt-get install jq

# Linux (RHEL/CentOS)
sudo yum install jq
```

#### 6. **Permission Denied**

**Cause:** Scripts not executable

**Solution:**
```bash
# Make all scripts executable
chmod +x *.sh
```

### Debug Mode

To enable detailed output for debugging:

```bash
# Add at the beginning of any script
set -x  # Enable debug mode

# Or run with bash -x
bash -x ./api_creator.sh
```

### Verify Configuration

```bash
# Check environment configuration
source config.env
echo "Host: $HOST"
echo "Admin: $ADMIN_USERNAME"
echo "Servlet Port: $SERVLET_PORT"
echo "Number of Apps: $NUM_APPS"
```

### Check APIM Status

```bash
# Check if APIM is running
ps aux | grep wso2

# Check APIM logs
tail -f {APIM_HOME}/repository/logs/wso2carbon.log

# Test API endpoint
curl -k https://localhost:9443/api/am/publisher/v2/apis \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

## Best Practices

1. **Start Small:** Begin with a small number of apps (e.g., `NUM_APPS=5`) to test the setup
2. **Verify Each Step:** Run scripts one at a time and verify results before proceeding
3. **Check Logs:** Monitor WSO2 APIM logs for any errors
4. **Backup:** Before running scripts on production-like environments, backup your APIM database
5. **Clean CSV:** Ensure `apis.csv` has no empty lines or invalid URLs
6. **Network:** Ensure network connectivity to external API endpoints defined in `apis.csv`
7. **Resource Limits:** Be mindful of API rate limits on external endpoints

---

## Cleanup

To remove all generated data:

1. **Via APIM Console:**
   - Delete applications from Developer Portal
   - Delete APIs from Publisher Portal

2. **Via Database (if using MySQL):**
   ```sql
   -- Backup first!
   -- Then delete subscriptions, applications, and APIs
   -- Refer to WSO2 APIM database schema
   ```

3. **Fresh Start:**
   - Stop WSO2 APIM
   - Drop and recreate databases
   - Restart WSO2 APIM
   - Re-run scripts

---

## Additional Resources

- [WSO2 API Manager Documentation](https://apim.docs.wso2.com/)
- [WSO2 APIM REST APIs](https://apim.docs.wso2.com/en/latest/develop/product-apis/overview/)
- [Dynamic Client Registration](https://apim.docs.wso2.com/en/latest/develop/product-apis/dynamic-client-registration/)

---

## Support

For issues or questions:
1. Check the [README.md](README.md) file
2. Review WSO2 APIM logs
3. Consult WSO2 APIM documentation
4. Open an issue in the repository

---

## Version Compatibility

This toolkit has been tested with:
- WSO2 API Manager 3.2.0 & 4.0.0
- MySQL 5.8+
- JDK 11

For other versions, minor adjustments may be needed in the `deployment.toml` or API payload structures.
