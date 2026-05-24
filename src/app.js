const dropZone = document.getElementById('dropZone');
const fileInput = document.getElementById('fileInput');
const chooseFileBtn = document.getElementById('chooseFileBtn');
const statusArea = document.getElementById('statusArea');
const fileNameEl = document.getElementById('fileName');
const detectedVersionEl = document.getElementById('detectedVersion');
const officialVersionEl = document.getElementById('officialVersion');
const overrideArea = document.getElementById('overrideArea');
const targetVersionInput = document.getElementById('targetVersion');
const actions = document.getElementById('actions');
const fixBtn = document.getElementById('fixBtn');
const message = document.getElementById('message');

let currentFile = null;
let currentVersion = null;
let officialVersion = null;

// --- Event Listeners ---

['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
    dropZone.addEventListener(eventName, preventDefaults, false);
    document.body.addEventListener(eventName, preventDefaults, false);
});

['dragenter', 'dragover'].forEach(eventName => {
    dropZone.addEventListener(eventName, () => dropZone.classList.add('drag-over'), false);
});

['dragleave', 'drop'].forEach(eventName => {
    dropZone.addEventListener(eventName, () => dropZone.classList.remove('drag-over'), false);
});

dropZone.addEventListener('drop', handleDrop, false);
dropZone.addEventListener('click', () => fileInput.click());
chooseFileBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    fileInput.click();
});
fileInput.addEventListener('change', (e) => {
    if (e.target.files.length) handleFile(e.target.files[0]);
});
fixBtn.addEventListener('click', fixAndDownload);

function preventDefaults(e) {
    e.preventDefault();
    e.stopPropagation();
}

function handleDrop(e) {
    const dt = e.dataTransfer;
    const files = dt.files;
    if (files.length) handleFile(files[0]);
}

// --- Main Logic ---

async function handleFile(file) {
    if (!file.name.toLowerCase().endsWith('.3mf')) {
        showMessage('Please drop a .3mf file', 'error');
        return;
    }

    currentFile = file;
    showMessage('Reading 3MF archive...');

    try {
        const zip = await JSZip.loadAsync(file);

        // Detect current version
        currentVersion = await detectVersion(zip);
        if (!currentVersion) {
            showMessage('Could not detect Bambu Studio version in this 3MF file', 'error');
            resetUI();
            return;
        }

        // Fetch official version
        officialVersion = await fetchLatestOfficialVersion();
        if (!officialVersion) {
            showMessage('Could not fetch latest official version from GitHub. You can still enter a version manually.', 'error');
            officialVersion = '02.06.00.51'; // fallback
        }

        // Update UI
        fileNameEl.textContent = file.name;
        detectedVersionEl.textContent = currentVersion;
        officialVersionEl.textContent = officialVersion;
        targetVersionInput.value = officialVersion;

        statusArea.style.display = 'block';
        overrideArea.style.display = 'block';
        actions.style.display = 'block';
        fixBtn.disabled = false;
        showMessage('Ready to fix. You can override the target version if needed.', 'success');

    } catch (err) {
        console.error(err);
        showMessage('Error reading 3MF file: ' + err.message, 'error');
        resetUI();
    }
}

async function detectVersion(zip) {
    // Try project_settings.config first
    const projectConfig = zip.file('Metadata/project_settings.config');
    if (projectConfig) {
        const text = await projectConfig.async('text');
        const match = text.match(/"version"\s*:\s*"([^"]+)"/);
        if (match) return match[1];
    }

    // Try slice_info.config
    const sliceInfo = zip.file('Metadata/slice_info.config');
    if (sliceInfo) {
        const text = await sliceInfo.async('text');
        const match = text.match(/value="(\d+\.\d+\.\d+\.\d+)"/);
        if (match) return match[1];
    }

    // Try 3dmodel.model
    const model = zip.file('3D/3dmodel.model');
    if (model) {
        const text = await model.async('text');
        const match = text.match(/BambuStudio-(\d+\.\d+\.\d+\.\d+)/);
        if (match) return match[1];
    }

    return null;
}

async function fetchLatestOfficialVersion() {
    try {
        const res = await fetch('https://api.github.com/repos/bambulab/BambuStudio/releases/latest');
        if (!res.ok) return null;
        const data = await res.json();
        const tag = data.tag_name;
        return tag ? tag.replace(/^v/, '') : null;
    } catch {
        return null;
    }
}

async function fixAndDownload() {
    if (!currentFile || !currentVersion) return;

    const targetVersion = targetVersionInput.value.trim();
    if (!targetVersion) {
        showMessage('Please enter a target version', 'error');
        return;
    }

    fixBtn.disabled = true;
    fixBtn.textContent = 'Processing...';
    showMessage('Replacing version strings and repackaging...');

    try {
        const zip = await JSZip.loadAsync(currentFile);

        const filesToPatch = [
            '3D/3dmodel.model',
            'Metadata/slice_info.config',
            'Metadata/project_settings.config'
        ];

        let patchedCount = 0;

        for (const path of filesToPatch) {
            const file = zip.file(path);
            if (!file) continue;

            let text = await file.async('text');
            let changed = false;

            // Replace plain version (e.g., 02.07.00.55)
            const plainRegex = new RegExp(currentVersion.replace(/\./g, '\\.'), 'g');
            if (plainRegex.test(text)) {
                text = text.replace(plainRegex, targetVersion);
                changed = true;
            }

            // Replace Application format (BambuStudio-02.07.00.55)
            const appOld = 'BambuStudio-' + currentVersion;
            const appNew = 'BambuStudio-' + targetVersion;
            if (text.includes(appOld)) {
                text = text.split(appOld).join(appNew);
                changed = true;
            }

            if (changed) {
                zip.file(path, text);
                patchedCount++;
            }
        }

        if (patchedCount === 0) {
            showMessage('No version strings were found to replace. The file may have an unexpected format.', 'error');
            fixBtn.disabled = false;
            fixBtn.textContent = 'Fix & Download';
            return;
        }

        // Generate new ZIP
        const blob = await zip.generateAsync({ type: 'blob', mimeType: 'application/vnd.ms-package.3dmanufacturing-3dmodel+xml' });

        // Trigger download
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        const baseName = currentFile.name.replace(/\.3mf$/i, '');
        a.href = url;
        a.download = `${baseName}_fixed.3mf`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

        showMessage(`Done! Downloaded ${patchedCount} file(s) patched.`, 'success');
        fixBtn.textContent = 'Fix & Download';
        fixBtn.disabled = false;

    } catch (err) {
        console.error(err);
        showMessage('Error: ' + err.message, 'error');
        fixBtn.disabled = false;
        fixBtn.textContent = 'Fix & Download';
    }
}

function resetUI() {
    statusArea.style.display = 'none';
    overrideArea.style.display = 'none';
    actions.style.display = 'none';
    fixBtn.disabled = true;
    currentFile = null;
    currentVersion = null;
    officialVersion = null;
}

function showMessage(text, type = '') {
    message.textContent = text;
    message.className = 'message' + (type ? ' ' + type : '');
}
