# WSO2 APIM Mock Data Generator

Automated mock data generator for WSO2 API Manager. Spins up a fresh APIM instance (or targets an existing one), creates APIs, publishes them, generates DevPortal applications, generates OAuth keys, and subscribes applications to APIs — then dumps the MySQL databases as a release artifact.

---

## Branch Structure

| Branch | Purpose |
|---|---|
| `main` | Multi-version workflow hub — run the workflow from here |
| `wso2am-4.5.0` | Version-specific scripts for APIM 4.5.0 |
| `wso2am-4.1.0` | Version-specific scripts for APIM 4.1.0 |
| `wso2am-4.0.0` | Version-specific scripts for APIM 4.0.0 |
| `wso2am-3.2.0` | Version-specific scripts for APIM 3.2.0 |

Each `wso2am-X.Y.Z` branch holds the correct API endpoint scripts for that version. The `main` branch workflow automatically fetches the right scripts at runtime — you never need to switch branches manually.

---

## Running the Workflow

Go to **Actions → WSO2 APIM Dummy Data Generator → Run workflow** and fill in:

| Input | Description | Default |
|---|---|---|
| `apim_version` | Target APIM version | `4.5.0` |
| `host` | APIM host (`localhost` spins up a fresh instance) | `localhost` |
| `admin_username` | APIM admin username | `admin` |
| `admin_password` | APIM admin password | `admin` |
| `num_apps` | Number of DevPortal applications to create | `15` |
| `subscription` | WSO2 subscription available? (enables U2 updates) | `false` |
| `U2_lvl` | Specific U2 update level (optional) | — |

### `host: localhost` (default)

Downloads the APIM pack, sets up MySQL, starts the server, generates mock data, dumps the databases, and uploads the dump as a GitHub Actions artifact. A GitHub Release is also created automatically.

### `host: <your-server>`

Skips the server setup steps entirely. Runs the data generation scripts directly against your existing APIM instance.

---

## Using a Released DB Dump

Each workflow run produces a MySQL dump under **Releases**:

```
mysql_dumps-wso2am-X.Y.Z-YYYY-MM-DD-HH-MM-SS.zip
├── WSO2_APIM_DB.sql
└── WSO2_SHARED_DB.sql
```

To restore against your own APIM instance:

```bash
# 1. Create databases
mysql -uroot -p -e "
  CREATE DATABASE IF NOT EXISTS WSO2_APIM_DB CHARACTER SET latin1;
  CREATE DATABASE IF NOT EXISTS WSO2_SHARED_DB CHARACTER SET latin1;
  CREATE USER IF NOT EXISTS 'wso2carbon'@'localhost' IDENTIFIED BY 'wso2carbon';
  GRANT ALL PRIVILEGES ON WSO2_APIM_DB.* TO 'wso2carbon'@'localhost';
  GRANT ALL PRIVILEGES ON WSO2_SHARED_DB.* TO 'wso2carbon'@'localhost';
  FLUSH PRIVILEGES;
"

# 2. Restore dumps
mysql -uwso2carbon -pwso2carbon WSO2_APIM_DB  < WSO2_APIM_DB.sql
mysql -uwso2carbon -pwso2carbon WSO2_SHARED_DB < WSO2_SHARED_DB.sql
```

Then start your APIM instance pointing at those databases via `deployment.toml`. The MySQL connector JAR and default `wso2carbon.jks` already ship inside the APIM pack — no extra files needed.

---

## Running Scripts Locally

For local execution, check out the relevant version branch directly:

```bash
git checkout wso2am-4.5.0   # or 4.1.0 / 4.0.0 / 3.2.0
```

Copy `config.env.template` to `config.env` and fill in your values:

```bash
cp config.env.template config.env
vi config.env
```

Then run the scripts in order:

```bash
chmod +x api_creator.sh api_publisher.sh devportal_app_creator.sh app_keys_gen.sh subscribe_APIs.sh

./api_creator.sh              # Create APIs from apis.csv
./api_publisher.sh            # Publish all CREATED APIs
./devportal_app_creator.sh    # Create DevPortal test applications
./app_keys_gen.sh             # Generate production + sandbox OAuth keys
./subscribe_APIs.sh           # Subscribe every app to every API
```

> `config.env` is git-ignored — credentials are never committed.

---

## Version Compatibility

| Branch | APIM Version | Publisher API | DevPortal API | JDK |
|---|---|---|---|---|
| `wso2am-4.5.0` | 4.5.0 | v4 | v3 | 11 |
| `wso2am-4.1.0` | 4.1.0 | v3 | v3 | 11 |
| `wso2am-4.0.0` | 4.0.0 | v2 | v2 | 11 |
| `wso2am-3.2.0` | 3.2.0 | v1 | v1 (store) | 8 |

---

## Adding a New APIM Version

1. Create a new branch from the closest existing version branch:
   ```bash
   git checkout wso2am-4.5.0
   git checkout -b wso2am-X.Y.Z
   ```
2. Update the scripts for the new API endpoint versions.
3. Add `X.Y.Z` to the `apim_version` choices in `.github/workflows/wso2-apim-data-gen.yml` on `main`.
4. Push the new branch.

---

## Secrets Required

| Secret | Used for |
|---|---|
| `GIT_ACTION_PAT` | Creating GitHub Releases |
| `WSO2_USERNAME` | U2 updates (only when `subscription: true`) |
| `WSO2_PASSWORD` | U2 updates (only when `subscription: true`) |
