import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

import {
  LEGACY_CREDENTIALS_KEY,
  REMEMBERED_ACCOUNT_KEY,
  loadRememberedIdentifier,
  persistRememberedIdentifier
} from '../src/utils/rememberedAccount.ts'

class MemoryStorage {
  private readonly values = new Map<string, string>()

  getItem(key: string): string | null {
    return this.values.get(key) ?? null
  }

  setItem(key: string, value: string): void {
    this.values.set(key, value)
  }

  removeItem(key: string): void {
    this.values.delete(key)
  }
}

test('legacy saved credentials are migrated to an identifier without retaining the password', () => {
  const storage = new MemoryStorage()
  storage.setItem(LEGACY_CREDENTIALS_KEY, JSON.stringify({
    email: ' admin@example.com ',
    password: 'plain-text-secret'
  }))

  assert.equal(loadRememberedIdentifier(storage), 'admin@example.com')
  assert.equal(storage.getItem(LEGACY_CREDENTIALS_KEY), null)

  const savedAccount = storage.getItem(REMEMBERED_ACCOUNT_KEY)
  assert.ok(savedAccount)
  assert.deepEqual(JSON.parse(savedAccount), { identifier: 'admin@example.com' })
  assert.doesNotMatch(savedAccount, /plain-text-secret|password/i)
})

test('remember account stores a username identifier and unchecking removes all remembered data', () => {
  const storage = new MemoryStorage()

  persistRememberedIdentifier(storage, ' admin ', true)
  assert.deepEqual(JSON.parse(storage.getItem(REMEMBERED_ACCOUNT_KEY) ?? '{}'), {
    identifier: 'admin'
  })

  persistRememberedIdentifier(storage, 'admin', false)
  assert.equal(storage.getItem(REMEMBERED_ACCOUNT_KEY), null)
  assert.equal(storage.getItem(LEGACY_CREDENTIALS_KEY), null)
})

test('bootstrap removes legacy plaintext credentials before cookie restore', () => {
  const main = readFileSync(
    fileURLToPath(new URL('../src/main.ts', import.meta.url)),
    'utf8'
  )

  assert.match(main, /loadRememberedIdentifier\(localStorage\)/)
  assert.ok(
    main.indexOf('loadRememberedIdentifier(localStorage)') <
      main.indexOf('await authStore.restoreSession()')
  )
})

test('current remembered email data migrates to the identifier shape', () => {
  const storage = new MemoryStorage()
  storage.setItem(REMEMBERED_ACCOUNT_KEY, JSON.stringify({
    email: ' admin@example.com '
  }))

  assert.equal(loadRememberedIdentifier(storage), 'admin@example.com')
  assert.deepEqual(JSON.parse(storage.getItem(REMEMBERED_ACCOUNT_KEY) ?? '{}'), {
    identifier: 'admin@example.com'
  })
})
