import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
import { fileURLToPath } from 'node:url'
import { AxiosError, type AxiosAdapter, type InternalAxiosRequestConfig } from 'axios'

import { createHttpClient } from '../src/api/httpClient.ts'

function readSource(relativePath: string): string {
  return readFileSync(fileURLToPath(new URL(`../src/${relativePath}`, import.meta.url)), 'utf8')
}

function ok(config: InternalAxiosRequestConfig, data: unknown = {}) {
  return Promise.resolve({
    data,
    status: 200,
    statusText: 'OK',
    headers: {},
    config
  })
}

function unauthorized(config: InternalAxiosRequestConfig): Promise<never> {
  const response = {
    data: { code: 401, message: 'Unauthorized' },
    status: 401,
    statusText: 'Unauthorized',
    headers: {},
    config
  }

  return Promise.reject(new AxiosError(
    'Request failed with status code 401',
    AxiosError.ERR_BAD_REQUEST,
    config,
    undefined,
    response
  ))
}

test('concurrent 401 responses share one cookie refresh and replay every request', async () => {
  let sessionRefreshed = false
  let refreshCalls = 0
  const requestCalls = new Map<string, number>()
  let releaseRefresh: (() => void) | undefined
  const refreshGate = new Promise<void>((resolve) => {
    releaseRefresh = resolve
  })

  const apiAdapter: AxiosAdapter = async (config) => {
    const url = config.url ?? ''
    requestCalls.set(url, (requestCalls.get(url) ?? 0) + 1)
    if (!sessionRefreshed) return unauthorized(config)
    return ok(config, { url })
  }
  const authAdapter: AxiosAdapter = async (config) => {
    if (config.url === '/api/auth/me') {
      return sessionRefreshed ? ok(config) : unauthorized(config)
    }

    refreshCalls += 1
    assert.equal(config.url, '/api/auth/refresh')
    assert.deepEqual(JSON.parse(String(config.data)), {})
    await refreshGate
    sessionRefreshed = true
    return ok(config)
  }

  const { api } = createHttpClient({ apiAdapter, authAdapter })
  const first = api.get('/api/tracks')
  const second = api.get('/api/admin/users')

  await new Promise((resolve) => setImmediate(resolve))
  assert.equal(refreshCalls, 1)
  releaseRefresh?.()

  const [tracks, users] = await Promise.all([first, second])
  assert.equal(tracks.status, 200)
  assert.equal(users.status, 200)
  assert.equal(requestCalls.get('/api/tracks'), 2)
  assert.equal(requestCalls.get('/api/admin/users'), 2)
})

test('one failed refresh expires the UI session once for concurrent requests', async () => {
  let refreshCalls = 0
  let expiredCalls = 0
  let releaseRefresh: (() => void) | undefined
  const refreshGate = new Promise<void>((resolve) => {
    releaseRefresh = resolve
  })

  const apiAdapter: AxiosAdapter = (config) => unauthorized(config)
  const authAdapter: AxiosAdapter = async (config) => {
    if (config.url === '/api/auth/me') return unauthorized(config)
    refreshCalls += 1
    await refreshGate
    return unauthorized(config)
  }

  const { api, setSessionExpiredHandler } = createHttpClient({ apiAdapter, authAdapter })
  setSessionExpiredHandler(() => {
    expiredCalls += 1
  })

  const requests = [api.get('/api/tracks'), api.get('/api/admin/users')]
  await new Promise((resolve) => setImmediate(resolve))
  releaseRefresh?.()
  const results = await Promise.allSettled(requests)

  assert.equal(refreshCalls, 1)
  assert.equal(expiredCalls, 1)
  assert.ok(results.every((result) => result.status === 'rejected'))
})

test('login 401 does not attempt to refresh an absent browser session', async () => {
  let refreshCalls = 0
  const apiAdapter: AxiosAdapter = (config) => unauthorized(config)
  const authAdapter: AxiosAdapter = async (config) => {
    refreshCalls += 1
    return ok(config)
  }

  const { api } = createHttpClient({ apiAdapter, authAdapter })
  await assert.rejects(api.post('/api/auth/login', {
    identifier: 'admin',
    password: 'secret',
    tokenTransport: 'cookie'
  }))
  assert.equal(refreshCalls, 0)
})

test('login UI and store use the username-or-email identifier contract', () => {
  const store = readSource('stores/auth.ts')
  const login = readSource('views/auth/LoginView.vue')

  assert.match(store, /async function login\(identifier: string, password: string\)/)
  assert.match(store, /\{\s*identifier,\s*password,\s*tokenTransport:\s*['"]cookie['"]/s)
  assert.doesNotMatch(store, /async function login\(email:/)
  assert.match(login, /用户名或邮箱/)
  assert.doesNotMatch(login, /type:\s*['"]email['"]/)
})

test('a replayed request that remains unauthorized expires the UI session once', async () => {
  let requestCalls = 0
  let refreshCalls = 0
  let expiredCalls = 0
  const apiAdapter: AxiosAdapter = (config) => {
    requestCalls += 1
    return unauthorized(config)
  }
  const authAdapter: AxiosAdapter = async (config) => {
    if (config.url === '/api/auth/me') return unauthorized(config)
    refreshCalls += 1
    assert.equal(config.url, '/api/auth/refresh')
    return ok(config)
  }

  const { api, setSessionExpiredHandler } = createHttpClient({ apiAdapter, authAdapter })
  setSessionExpiredHandler(() => {
    expiredCalls += 1
  })

  await assert.rejects(api.get('/api/admin/users'))
  assert.equal(requestCalls, 2)
  assert.equal(refreshCalls, 1)
  assert.equal(expiredCalls, 1)
})

test('cross-tab refresh coordination rechecks the access cookie before rotating', async () => {
  const originalNavigator = Object.getOwnPropertyDescriptor(globalThis, 'navigator')
  let lockTail = Promise.resolve()
  const locks = {
    request: async <T>(_name: string, callback: () => Promise<T>): Promise<T> => {
      const previous = lockTail
      let releaseLock: (() => void) | undefined
      lockTail = new Promise<void>((resolve) => {
        releaseLock = resolve
      })
      await previous
      try {
        return await callback()
      } finally {
        releaseLock?.()
      }
    }
  }
  Object.defineProperty(globalThis, 'navigator', {
    configurable: true,
    value: { locks }
  })

  let accessCookieValid = false
  let refreshCalls = 0
  const authAdapter: AxiosAdapter = async (config) => {
    if (config.url === '/api/auth/me') {
      return accessCookieValid ? ok(config) : unauthorized(config)
    }
    assert.equal(config.url, '/api/auth/refresh')
    refreshCalls += 1
    accessCookieValid = true
    return ok(config)
  }

  try {
    const firstTab = createHttpClient({ authAdapter })
    const secondTab = createHttpClient({ authAdapter })
    await Promise.all([
      firstTab.refreshSession(),
      secondTab.refreshSession()
    ])
    assert.equal(refreshCalls, 1)
  } finally {
    if (originalNavigator) {
      Object.defineProperty(globalThis, 'navigator', originalNavigator)
    } else {
      Reflect.deleteProperty(globalThis, 'navigator')
    }
  }
})

test('auth state never reads or writes bearer tokens in browser storage', () => {
  const api = readSource('api/index.ts')
  const store = readSource('stores/auth.ts')
  const tracks = readSource('views/music/TracksView.vue')
  const combined = `${api}\n${store}\n${tracks}`

  assert.doesNotMatch(combined, /localStorage\.(?:getItem|setItem)\(['"](?:token|refreshToken)['"]/)
  assert.doesNotMatch(combined, /Authorization|Bearer/)
  assert.doesNotMatch(store, /const\s+(?:token|refreshToken)\s*=\s*ref/)
  assert.match(store, /tokenTransport\s*:\s*['"]cookie['"]/)
  assert.match(store, /localStorage\.removeItem\(['"]token['"]\)/)
  assert.match(store, /localStorage\.removeItem\(['"]refreshToken['"]\)/)
})

test('startup restores the cookie session before mounting protected routes', () => {
  const main = readSource('main.ts')
  const router = readSource('router/index.ts')
  const store = readSource('stores/auth.ts')
  const httpClient = readSource('api/httpClient.ts')
  const restoreBody = store.match(
    /async function restoreSession\(\)(?:\s*:\s*Promise<boolean>)?\s*\{([\s\S]*?)\n\s*\}/
  )?.[1] ?? ''

  assert.match(store, /async function restoreSession/)
  assert.match(restoreBody, /\/api\/auth\/me/)
  assert.doesNotMatch(restoreBody, /\/api\/auth\/refresh/)
  assert.match(httpClient, /navigator\.locks[\s\S]*?\.request/)
  assert.match(main, /await authStore\.restoreSession\(\)/)
  assert.ok(
    main.indexOf('await authStore.restoreSession()') < main.indexOf("app.mount('#app')"),
    'session restore must finish before the application mounts'
  )
  assert.match(router, /authStore\.isRestored/)
  assert.match(router, /await authStore\.restoreSession\(\)/)
})

test('logout awaits server revocation before clearing UI state', () => {
  const store = readSource('stores/auth.ts')
  const layout = readSource('layouts/AdminLayout.vue')

  const logout = store.match(
    /async function logout\(\)(?:\s*:\s*Promise<void>)?\s*\{([\s\S]*?)\n\s*\}/
  )?.[1] ?? ''
  assert.match(logout, /await api\.post\(['"]\/api\/auth\/logout['"]\)/)
  assert.ok(logout.indexOf('await api.post') < logout.indexOf('clearSession()'))
  assert.match(layout, /async function handleCommand/)
  assert.match(layout, /await authStore\.logout\(\)/)
})
