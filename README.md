# Bambu 3MF Version Fixer

A minimal, client-side web tool to fix Bambu Studio `.3mf` files for MakerWorld compatibility.

When Bambu Studio beta versions save `.3mf` files, MakerWorld rejects them with:
> "Unsupported 3mf version. Please make sure the 3mf file was created with the official version of Bambu Studio, not a beta version."

This tool patches the embedded version metadata in the 3MF archive to match the latest **official stable release** — fetched live from the [Bambu Studio GitHub releases page](https://github.com/bambulab/BambuStudio/releases).

**Your files never leave your browser.** All processing happens client-side with [JSZip](https://stuk.github.io/jszip/).

---

## Features

- Drag & drop or native file picker
- Auto-detects the Bambu Studio version inside the 3MF
- Fetches the latest official release from GitHub API
- Editable version override (in case you want a specific target)
- Rebuilds and downloads the fixed `.3mf` instantly
- Catppuccin Mocha theme

---

## Quick Start (Anywhere)

1. Open `src/index.html` directly in your browser.
2. Drag a `.3mf` file onto the page.
3. Click **Fix & Download**.

> **Note:** When opened as `file://`, the GitHub API fetch may be blocked by CORS. In that case, the fallback version `02.06.00.51` is used, and you can still override it manually.

---

## Synology Deployment (Docker + Task Scheduler)

### 1. Clone or copy this repo to your Synology

Place it somewhere persistent, e.g.:
```bash
/volume1/docker/bambu-3mf-version-fixer/
```

### 2. Run the deploy script

SSH into your Synology as admin, then:
```bash
cd /volume1/docker/bambu-3mf-version-fixer
bash deploy.sh
```

This will:
- Stop & remove any existing container
- Build a fresh Docker image
- Start the container on port **8765**

### 3. (Optional) Set up Task Scheduler for one-click redeploy

1. Open **DSM** → **Control Panel** → **Task Scheduler**
2. Click **Create** → **Triggered Task** → **User-defined script**
3. General settings:
   - **Task:** `Bambu 3MF Fixer Deploy`
   - **User:** `root`
4. Task Settings → Run command:
   ```bash
   cd /volume1/docker/bambu-3mf-version-fixer && bash deploy.sh
   ```
5. Click **OK**, then **Run** whenever you want to redeploy (e.g., after pulling updates).

### 4. Access the app

```
http://<your-synology-ip>:8765
```

---

## Docker Compose (Alternative)

If you prefer `docker-compose`:

```bash
cd /volume1/docker/bambu-3mf-version-fixer
docker-compose up -d --build
```

---

## CLI Usage

A bash script is also included for headless / batch processing:

```bash
bash fix_3mf_version.sh ~/Downloads/my_model.3mf
```

This creates `my_model_fixed.3mf` next to the original.

---

## License

MIT — See [LICENSE](LICENSE).
