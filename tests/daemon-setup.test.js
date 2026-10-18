const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const test = require('node:test');

test('explicit setup enables the user daemon now and at future logins without a shell', () => {
  const context = {};
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(`${__dirname}/../overlay/DaemonSetup.js`, 'utf8').replace(/^\.pragma.*$/m, ''), context);
  const commands = [];
  context.enableAtLogin(command => commands.push(Array.from(command)));
  assert.deepEqual(commands, [['systemctl', '--user', 'enable', '--now', 'clipdeckd.service']]);
});
