import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

const nginx = readFileSync(
  fileURLToPath(new URL('../nginx.conf', import.meta.url)),
  'utf8'
)

test('proxies API media before matching frontend asset extensions', () => {
  assert.match(nginx, /location \^~ \/api\/ \{/)
  assert.equal((nginx.match(/proxy_pass\s+http:\/\/api:5000/g) ?? []).length, 2)
  assert.match(
    nginx,
    /location ~\* \\.\(js\|css\|png\|jpg\|jpeg\|gif\|ico\|svg\|woff\|woff2\)\$/
  )
})
