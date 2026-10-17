const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

const ctx = vm.createContext({});
const src = fs.readFileSync(__dirname + '/../overlay/DeckTheme.js', 'utf8')
  .replace(/^\s*\.pragma\s+library\s*;?/m, '// pragma library');
vm.runInContext(src, ctx);

test('markup caps oversized lines to avoid UI hang in Qt RichText', () => {
  const pal = { comment: "#888", keyword: "#f00", text: "#fff" };
  const lines = [];
  for (let i = 0; i < 150; i++) {
    lines.push('<span class="t-text">line ' + i + '</span>');
  }
  const bigInput = lines.join('<br/>');
  const rendered = ctx.markup(bigInput, pal);

  assert.ok(rendered.length > 0);
  assert.ok(rendered.includes('more lines not shown in preview'));
  const renderedLines = rendered.split('<br/>');
  assert.ok(renderedLines.length <= 92, `Expected <= 92 lines, got ${renderedLines.length}`);
});

test('markup handles normal-sized snippets without truncation', () => {
  const pal = { comment: "#888", keyword: "#f00", text: "#fff" };
  const input = '<span class="t-keyword">const</span> <span class="t-text">x = 1</span>';
  const rendered = ctx.markup(input, pal);
  assert.ok(rendered.includes('style="color:#f00"'));
  assert.ok(!rendered.includes('more lines not shown in preview'));
});

test('isRTL detects Persian and Arabic text and rejects Latin code', () => {
  assert.equal(ctx.isRTL('سلام دنیا'), true);
  assert.equal(ctx.isRTL('function test() { return 42; }'), false);
  assert.equal(ctx.isRTL(''), false);
  assert.equal(ctx.isRTL(null), false);
});
