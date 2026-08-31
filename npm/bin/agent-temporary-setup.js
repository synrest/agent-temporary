#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const cp = require('child_process');

const packageRoot = path.resolve(__dirname, '..');
const pkg = require(path.join(packageRoot, 'package.json'));
const payload = path.join(packageRoot, 'payload');
const manifestPath = path.join(packageRoot, 'manifest.json');

function fail(message) {
  process.stderr.write(`agent-temporary-setup: ${message}\n`);
  process.exitCode = 1;
}

function usage() {
  process.stdout.write('Usage:\n' +
    '  agent-temporary-setup install\n' +
    '  agent-temporary-setup update\n' +
    '  agent-temporary-setup status\n' +
    '  agent-temporary-setup uninstall-system\n');
}

function versionParts(value) {
  const match = /^([0-9]+)\.([0-9]+)\.([0-9]+)$/.exec(value || '');
  return match ? match.slice(1).map(Number) : null;
}

function compareVersions(left, right) {
  const a = versionParts(left);
  const b = versionParts(right);
  if (!a || !b) return null;
  for (let i = 0; i < 3; i += 1) {
    if (a[i] !== b[i]) return a[i] < b[i] ? -1 : 1;
  }
  return 0;
}

function verifyPayload() {
  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  } catch (error) {
    throw new Error(`cannot read payload manifest: ${error.message}`);
  }
  if (manifest.version !== pkg.version || manifest.payload_version !== pkg.version) {
    throw new Error('package version and embedded payload version do not match');
  }
  const version = fs.readFileSync(path.join(payload, 'VERSION'), 'utf8').trim();
  if (version !== pkg.version) throw new Error('embedded VERSION does not match package version');
  const checksumFile = path.join(packageRoot, manifest.payload_checksums || 'payload/SHA256SUMS');
  const lines = fs.readFileSync(checksumFile, 'utf8').trim().split(/\n/).filter(Boolean);
  if (!lines.length) throw new Error('embedded payload checksums are empty');
  for (const line of lines) {
    const match = /^([0-9a-f]{64})\s+(.+)$/.exec(line);
    if (!match) throw new Error(`malformed payload checksum line: ${line}`);
    const relative = match[2];
    const resolved = path.resolve(payload, relative);
    if (resolved !== payload && !resolved.startsWith(`${payload}${path.sep}`)) {
      throw new Error(`payload checksum escapes payload: ${relative}`);
    }
    const actual = crypto.createHash('sha256').update(fs.readFileSync(resolved)).digest('hex');
    if (actual !== match[1]) throw new Error(`payload integrity check failed: ${relative}`);
  }
  for (const required of ['install.sh', 'uninstall.sh', 'agent-temporary', 'VERSION']) {
    if (!fs.existsSync(path.join(payload, required))) throw new Error(`payload is missing ${required}`);
  }
}

function installedSystem() {
  const result = cp.spawnSync('agent-temporary', ['version'], { encoding: 'utf8' });
  if (result.error || result.status !== 0) return { present: false, version: null };
  const output = `${result.stdout || ''}${result.stderr || ''}`;
  const match = /agent-temporary\s+([^\s]+)/.exec(output);
  return { present: true, version: match ? match[1] : null };
}

function runSudo(args) {
  return cp.spawnSync('sudo', args, { stdio: 'inherit' });
}

function verifyInactive() {
  const result = cp.spawnSync('sudo', ['agent-temporary', 'status'], { encoding: 'utf8' });
  if (result.error || result.status !== 0) throw new Error('could not verify final system status');
  const output = `${result.stdout || ''}${result.stderr || ''}`;
  process.stdout.write(output);
  if (!/^state=inactive$/m.test(output) || !/^effective_authority=false$/m.test(output)) {
    throw new Error('system installation is not inactive after setup');
  }
}

function doStatus() {
  const system = installedSystem();
  process.stdout.write(`npm/package version=${pkg.version}\n`);
  process.stdout.write(`embedded payload version=${pkg.version}\n`);
  process.stdout.write(`system components=${system.present ? 'present' : 'absent/unknown'}\n`);
  process.stdout.write(`installed system version=${system.version || 'unknown'}\n`);
  if (!system.present) process.stdout.write('update available=no (system installation not detected)\n');
  else {
    const comparison = compareVersions(system.version, pkg.version);
    if (comparison === null) process.stdout.write('update available=unknown\n');
    else if (comparison < 0) process.stdout.write('update available=yes\n');
    else process.stdout.write('update available=no\n');
  }
}

function installOrUpdate(command) {
  verifyPayload();
  const system = installedSystem();
  const comparison = system.version ? compareVersions(system.version, pkg.version) : null;
  if (system.present && comparison === null) throw new Error('installed system version is unknown; refusing ambiguous installation');
  if (comparison > 0) throw new Error(`installed system version ${system.version} is newer than package version ${pkg.version}; downgrade is not supported`);
  if (command === 'update' && !system.present) throw new Error('no installed system detected; use install');
  if (comparison === 0) {
    process.stdout.write(`agent-temporary ${pkg.version} is already current; no system changes made.\n`);
    return;
  }
  process.stdout.write(`Installing agent-temporary ${pkg.version} system components.\nAdministrator privileges are required.\n`);
  const result = runSudo(['sh', path.join(payload, 'install.sh')]);
  if (result.error || result.status !== 0) throw new Error('system installer failed');
  const installed = installedSystem();
  if (!installed.present || installed.version !== pkg.version) throw new Error('installed system version verification failed');
  verifyInactive();
  process.stdout.write(`agent-temporary ${pkg.version} system installation is present and inactive.\n`);
}

function uninstallSystem() {
  verifyPayload();
  process.stdout.write('Removing agent-temporary system components. Administrator privileges are required.\n');
  const result = runSudo(['sh', path.join(payload, 'uninstall.sh')]);
  if (result.error || result.status !== 0) throw new Error('system uninstaller failed');
  const system = installedSystem();
  if (system.present) throw new Error('system command remains after uninstall');
  process.stdout.write('agent-temporary system installation removed.\n');
}

function main() {
  const command = process.argv[2];
  if (!command) return usage();
  if (command === '--help' || command === '-h') return usage();
  if (command === '--version') return process.stdout.write(`agent-temporary-setup ${pkg.version}\n`);
  if (!['status', 'install', 'update', 'uninstall-system'].includes(command)) {
    usage();
    process.exitCode = 2;
    return;
  }
  try {
    if (command === 'status') doStatus();
    else if (command === 'uninstall-system') uninstallSystem();
    else installOrUpdate(command);
  } catch (error) {
    fail(error.message);
  }
}

main();
