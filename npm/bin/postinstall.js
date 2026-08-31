#!/usr/bin/env node
'use strict';

const pkg = require('../package.json');
process.stdout.write(`agent-temporary ${pkg.version} installed.\n\n` +
  'System components are not installed automatically.\n' +
  'To finish setup:\n' +
  '  agent-temporary-setup install\n\n' +
  'This step will request administrator privileges.\n');
