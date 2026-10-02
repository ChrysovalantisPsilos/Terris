// node --test scripts/asc/store.test.mjs
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { displayTypeFor, planScreenshots, pngSize } from './store.mjs'

test('iPhone 6.9" and iPad 13" sizes map to their display types', () => {
  assert.equal(displayTypeFor([1290, 2796]), 'APP_IPHONE_67')
  assert.equal(displayTypeFor([1320, 2868]), 'APP_IPHONE_67')
  assert.equal(displayTypeFor([2048, 2732]), 'APP_IPAD_PRO_3GEN_129')
  assert.throws(() => displayTypeFor([1206, 2622]))
})

test('screenshots are grouped by display type, in file-name order', () => {
  const f = (path, size) => ({ path, size })
  const plan = planScreenshots([
    f('/x/iphone/02-country.png', [1290, 2796]),
    f('/x/ipad/01-map.png', [2048, 2732]),
    f('/x/iphone/01-map.png', [1290, 2796]),
  ])
  assert.deepEqual(plan.APP_IPHONE_67.map((x) => x.path), ['/x/iphone/01-map.png', '/x/iphone/02-country.png'])
  assert.deepEqual(plan.APP_IPAD_PRO_3GEN_129.map((x) => x.path), ['/x/ipad/01-map.png'])
})

test('reads a PNG size from its header', () => {
  const b = Buffer.alloc(24)
  b.writeUInt32BE(0x49484452, 12)
  b.writeUInt32BE(1290, 16)
  b.writeUInt32BE(2796, 20)
  assert.deepEqual(pngSize(b), [1290, 2796])
})
