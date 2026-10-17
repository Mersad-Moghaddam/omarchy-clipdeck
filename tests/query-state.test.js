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
test('secret previews are never prefetched', () => {
  assert.equal(ctx.mayPrefetch({sensitive:true}), false);
  assert.equal(ctx.mayPrefetch({sensitive:false}), true);
});
test('navigation loads near boundary and clamps when more pages exist', () => {
  // Arrow down near end triggers load
  const nearEnd = ctx.computeNavigation(194, 1, 200, true);
  assert.equal(nearEnd.index, 195);
  assert.equal(nearEnd.shouldLoad, true);

  // Arrow down at end clamps to edge and loads, does NOT wrap to top
  const atEndWithMore = ctx.computeNavigation(199, 1, 200, true);
  assert.equal(atEndWithMore.index, 199);
  assert.equal(atEndWithMore.shouldLoad, true);

  // Arrow down at end without more wraps to top
  const atEndNoMore = ctx.computeNavigation(199, 1, 200, false);
  assert.equal(atEndNoMore.index, 0);
  assert.equal(atEndNoMore.shouldLoad, false);

  // Arrow up at top wraps to bottom
  const atTop = ctx.computeNavigation(0, -1, 200, true);
  assert.equal(atTop.index, 199);
  assert.equal(atTop.shouldLoad, false);

  // PageDown overshooting end clamps to bottom and loads
  const pagedown = ctx.computeNavigation(198, 6, 200, true);
  assert.equal(pagedown.index, 199);
  assert.equal(pagedown.shouldLoad, true);
});
