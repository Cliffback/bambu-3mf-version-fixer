# Bambu 3MF Version Fixer

**[Live Web App →](https://cliffback.github.io/bambu-3mf-version-fixer/)**

A minimal, client-side web tool to fix Bambu Studio `.3mf` files for MakerWorld compatibility.

When Bambu Studio beta versions save `.3mf` files, MakerWorld rejects them with:
> "Unsupported 3mf version. Please make sure the 3mf file was created with the official version of Bambu Studio, not a beta version."

This tool patches the embedded version metadata in the 3MF archive to match the latest **official stable release** — fetched live from the [Bambu Studio GitHub releases page](https://github.com/bambulab/BambuStudio/releases).

**Your files never leave your browser.** All processing happens client-side with [JSZip](https://stuk.github.io/jszip/).

---

## Disclaimer

This tool is provided as-is for educational and convenience purposes. By using this tool, you acknowledge that **you are solely responsible** for any modifications made to your 3MF files, and for any consequences resulting from uploading modified files to MakerWorld or any other platform. The author assumes **no liability** for failed prints, account issues, rejected uploads, or any other outcome. Always verify your files before printing or publishing.

---

## Features

- Drag & drop or native file picker
- Auto-detects the Bambu Studio version inside the 3MF
- Fetches the latest official release from GitHub API
- Editable version override (in case you want a specific target)
- Rebuilds and downloads the fixed `.3mf` instantly
- Catppuccin Mocha theme

---

## Quick Start

**Option 1 — Use the live web app (recommended):**
1. Go to **[https://cliffback.github.io/bambu-3mf-version-fixer/](https://cliffback.github.io/bambu-3mf-version-fixer/)**
2. Drag a `.3mf` file onto the page.
3. Click **Fix & Download**.

**Option 2 — Run locally:**
1. Open `index.html` directly in your browser.
2. Drag a `.3mf` file onto the page.
3. Click **Fix & Download**.

> **Note:** When opened as `file://`, the GitHub API fetch may be blocked by CORS. In that case, the fallback version `02.06.00.51` is used, and you can still override it manually.

---

## Self-Hosting (Docker)

A `Dockerfile` and `docker-compose.yml` are included for self-hosting. To deploy:

```bash
bash deploy.sh
```

This builds an `nginx:alpine` image and serves the app on port **8765**.

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
