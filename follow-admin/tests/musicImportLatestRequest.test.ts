import assert from 'node:assert/strict'
import { existsSync } from 'node:fs'
import test from 'node:test'

interface Deferred<T> {
  promise: Promise<T>
  resolve: (value: T) => void
}

function deferred<T>(): Deferred<T> {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((resolvePromise) => {
    resolve = resolvePromise
  })
  return { promise, resolve }
}

async function loadLatest<T>(
  gate: { begin: () => number, isLatest: (token: number) => boolean },
  request: Promise<T>,
  apply: (value: T) => void
) {
  const token = gate.begin()
  const value = await request
  if (gate.isLatest(token)) apply(value)
}

async function loadGate() {
  const moduleUrl = new URL('../src/utils/latestRequest.ts', import.meta.url)
  assert.ok(existsSync(moduleUrl), 'latest-request gate should exist')
  return import(moduleUrl.href)
}

test('music import latest-request gate rejects a slower stale response', async () => {
  const { createLatestRequestGate } = await loadGate()
  const gate = createLatestRequestGate()
  const slower = deferred<string>()
  const newer = deferred<string>()
  let rendered = 'initial'

  const slowerLoad = loadLatest(gate, slower.promise, (value) => { rendered = value })
  const newerLoad = loadLatest(gate, newer.promise, (value) => { rendered = value })

  newer.resolve('newer')
  await newerLoad
  slower.resolve('stale')
  await slowerLoad

  assert.equal(rendered, 'newer')
})

test('music import action invalidation rejects reads started before the mutation', async () => {
  const { createLatestRequestGate } = await loadGate()
  const gate = createLatestRequestGate()
  const pending = deferred<string>()
  let rendered = 'before-action'
  const pendingLoad = loadLatest(gate, pending.promise, (value) => { rendered = value })

  gate.invalidate()
  pending.resolve('stale-before-action')
  await pendingLoad

  assert.equal(rendered, 'before-action')
})
