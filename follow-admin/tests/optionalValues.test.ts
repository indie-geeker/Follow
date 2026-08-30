import assert from 'node:assert/strict'
import test from 'node:test'

import { formatOptionalYear, normalizeOptionalYear } from '../src/utils/display.ts'

test('missing album years render as a quiet placeholder', () => {
  assert.equal(formatOptionalYear(null), '—')
  assert.equal(formatOptionalYear(undefined), '—')
  assert.equal(formatOptionalYear(0), '—')
  assert.equal(formatOptionalYear(2026), '2026')
})

test('missing album years stay nullable when submitted', () => {
  assert.equal(normalizeOptionalYear(null), null)
  assert.equal(normalizeOptionalYear(undefined), null)
  assert.equal(normalizeOptionalYear(Number.NaN), null)
  assert.equal(normalizeOptionalYear(1999), 1999)
})
