# WSO2 APIM Mock Data Generator

Automates the creation of mock APIs, applications, subscriptions, and OAuth keys in a WSO2 API Manager instance — useful for demos, testing, and performance benchmarking.

Supports WSO2 APIM **3.2.0, 4.0.0, 4.1.0, 4.5.0** (branch-per-version model).

---

## Option A — Use a pre-built release dump (fastest)

Every branch ships GitHub release artifacts containing pre-populated MySQL database dumps. You can restore these into a fresh APIM instance instead of running all the scripts yourself.

**Steps:**

1. **Download the release zip** from the [Releases](../../releases) page for your APIM version. It contains `WSO2_APIM_DB.sql` and `WSO2_SHARED_DB.sql`.

2. **Set up MySQL** and create the databases:
   ```bash
   mysql -uroot -p << EOF
   CREATE DATABASE WSO2_APIM_DB CHARACTER SET latin1;
   CREATE DATABASE WSO2_SHARED_DB CHARACTER SET latin1;
   CREATE USER 'wso2carbon'@'localhost' IDENTIFIED BY 'wso2carbon';
   GRANT ALL PRIVILEGES ON WSO2_APIM_DB.* TO 'wso2carbon'@'localhost';
   GRANT ALL PRIVILEGES ON WSO2_SHARED_DB.* TO 'wso2carbon'@'localhost';
   FLUSH PRIVILEGES;
   EOF
   ```

3. **Restore the dumps:**
   ```bash
   mysql -uwso2carbon -pwso2carbon WSO2_APIM_DB  < WSO2_APIM_DB.sql
   mysql -uwso2carbon -pwso2carbon WSO2_SHARED_DB < WSO2_SHARED_DB.sql
   ```

4. **Configure APIM to use MySQL.** Copy `deployment.toml` from this repo into your APIM pack:
   ```bash
   cp deployment.toml <APIM_HOME>/repository/conf/deployment.toml
   ```
   Also copy the MySQL connector JAR into `<APIM_HOME>/repository/components/lib/`.
   > No JKS files needed — the default `wso2carbon.jks` already ships inside the APIM pack.

5. **Start APIM:**
   ```bash
   <APIM_HOME>/bin/api-manager.sh start
   ```

---

## Option B — Generate fresh data from scripts

Use this if you want to generate new mock data against your own running APIM instance.

### Prerequisites

- Bash / Zsh
- `curl` and `jq` (`brew install jq` on macOS)
- A running WSO2 APIM instance (default: `https://localhost:9443`)

### Setup

```bash
# 1. Clone the correct branch for your APIM version
git clone -b wso2am-4.5.0 https://github.com/<your-org>/wso2-apim-mock-data-gen.git
cd wso2-apim-mock-data-gen

# 2. Create your local config
cp config.env.template config.env

# 3. Edit config.env with your host / credentials if different from defaults
vi config.env

# 4. Make scripts executable
chmod +x *.sh
```

### Run everything at once

```bash
./run-all.sh
```

### Or run step by step

```bash
./api_creator.sh          # Create APIs from apis.csv
./api_publisher.sh        # Publish all CREATED APIs
./devportal_app_creator.sh  # Create test applications
./app_keys_gen.sh         # Generate production + sandbox keys
./subscribe_APIs.sh       # Subscribe every app to every API
```

---

## Configuration

| File | Purpose |
|---|---|
| `config.env.template` | Template — copy to `config.env` and fill in |
| `config.env` | Your local config (git-ignored, never committed) |
| `apis.csv` | APIs to create (Name, Context, Endpoint) |
| `deployment.toml` | MySQL-backed APIM config for use with Option A |

### Adding your own APIs

Edit `apis.csv`:
```csv
API_Name,Context,Endpoint
MyAPI,myapi,https://my-backend.example.com/api
```

---

## GitHub Actions — generate data in CI

The workflow `wso2-apim-data-gen.yml` automates everything: downloads APIM, sets up MySQL, runs all scripts, dumps the DB, and publishes a release.

1. Go to **Actions → WSO2 APIM Dummy Data Generator**
2. Click **Run workflow**
3. Fill in `host`, credentials, `num_apps`, and optionally a WSO2 subscription update level
4. The resulting MySQL dumps are uploaded as a GitHub Release artifact

> Branch must be named `wso2am-X.Y.Z` (e.g. `wso2am-4.5.0`) — the workflow extracts the version from the branch name.

---

## Version compatibility

| Branch | APIM Version | Publisher API | DevPortal API |
|---|---|---|---|
| `wso2am-3.2.0` | 3.2.0 | v1 | v1 |
| `wso2am-4.0.0` | 4.0.0 | v2 | v2 |
| `wso2am-4.1.0` | 4.1.0 | v3 | v2 |
| `wso2am-4.5.0` | 4.5.0 | v4 | v3 |

---

## Troubleshooting

See [USAGE_GUIDE.md](USAGE_GUIDE.md) for detailed troubleshooting, script internals, and best practices.
