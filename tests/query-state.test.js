const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(__dirname + '/../overlay/QueryState.js', 'utf8'), ctx);
test('categories filter before pagination', () => {
  assert.equal(JSON.stringify(ctx.options('needle', 'code', 0)), JSON.stringify({query:'needle', types:['code','json'], pinned_only:false, limit:200, offset:0}));
  assert.equal(ctx.options('', 'pinned', 0).pinned_only, true);
});
test('generation guards reject old responses', () => {
  assert.equal(ctx.isCurrent(4, 5), false);
  assert.equal(ctx.isCurrent(5, 5), true);
});
test('pages cannot merge different queries', () => {
  assert.equal(ctx.canAppend(3, 4, 200, 200), false);
  assert.equal(ctx.canAppend(4, 4, 200, 100), false);
  assert.equal(ctx.canAppend(4, 4, 200, 200), true);
});
