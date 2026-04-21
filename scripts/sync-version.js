#!/usr/bin/env node
/**
 * sync-version.js
 *
 * Single source of truth: root "VERSION" file.
 * Propagates version to:
 *  - srv/frontend/package.json (version)
 *  - helm/values.yaml (global.imageTag)
 *  - All Chart.yaml files (appVersion)
 */
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const versionFile = path.join(root, 'VERSION');

if (!fs.existsSync(versionFile)) {
    console.error(`ERROR: VERSION file not found at ${versionFile}`);
    process.exit(1);
}

const version = fs.readFileSync(versionFile, 'utf-8').trim();
if (!version) {
    console.error("ERROR: VERSION file is empty");
    process.exit(1);
}

let updated = 0;

// 1. Update srv/frontend/package.json
const pkgPath = path.join(root, 'srv', 'frontend', 'package.json');
if (fs.existsSync(pkgPath)) {
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
    if (pkg.version !== version) {
        pkg.version = version;
        fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
        console.log(`  SYNC  srv/frontend/package.json → ${version}`);
        updated++;
    } else {
        console.log(`  OK    srv/frontend/package.json (already ${version})`);
    }
}

// 2. Update helm/values.yaml (global.imageTag)
const valuesPath = path.join(root, 'helm', 'values.yaml');
if (fs.existsSync(valuesPath)) {
    const content = fs.readFileSync(valuesPath, 'utf-8');
    const replaced = content.replace(/^([ \t]*imageTag:[ \t]*).*$/m, `$1${version}`);
    if (replaced !== content) {
        fs.writeFileSync(valuesPath, replaced);
        console.log(`  SYNC  helm/values.yaml (imageTag) → ${version}`);
        updated++;
    } else {
        console.log(`  OK    helm/values.yaml (imageTag already ${version})`);
    }
}

// 3. Update Chart.yaml files (appVersion)
const charts = [
    'helm/Chart.yaml',
    'srv/frontend/helm/Chart.yaml',
    'srv/backend/helm/Chart.yaml',
    'srv/wordd/helm/Chart.yaml',
];

for (const rel of charts) {
    const file = path.join(root, rel);
    if (!fs.existsSync(file)) {
        continue;
    }
    const original = fs.readFileSync(file, 'utf-8');
    const replaced = original.replace(/^appVersion:\s*".*"$/m, `appVersion: "${version}"`);
    if (replaced !== original) {
        fs.writeFileSync(file, replaced);
        console.log(`  SYNC  ${rel} (appVersion) → ${version}`);
        updated++;
    } else {
        console.log(`  OK    ${rel} (appVersion already ${version})`);
    }
}

console.log(`\n✔ version ${version} — ${updated} file(s) updated`);
