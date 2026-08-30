import axios, {
  type AxiosAdapter,
  type AxiosInstance,
  type InternalAxiosRequestConfig
} from 'axios'

interface RetryableRequestConfig extends InternalAxiosRequestConfig {
  _retry?: boolean
}

interface HttpClientOptions {
  apiAdapter?: AxiosAdapter
  authAdapter?: AxiosAdapter
  withCredentials?: boolean
}

interface HttpClientBundle {
  api: AxiosInstance
  refreshSession: () => Promise<void>
  setSessionExpiredHandler: (handler: () => void) => void
}

const AUTH_REQUESTS_WITHOUT_REFRESH = new Set([
  '/api/auth/login',
  '/api/auth/refresh'
])
const REFRESH_LOCK_NAME = 'follow-auth-refresh'

function requestPath(url?: string): string {
  return (url ?? '').split('?')[0] ?? ''
}

function isSessionRejection(error: unknown): boolean {
  return axios.isAxiosError(error) && error.response?.status === 401
}

export function createHttpClient(options: HttpClientOptions = {}): HttpClientBundle {
  const withCredentials = options.withCredentials ?? true
  const api = axios.create({
    timeout: 30000,
    withCredentials,
    adapter: options.apiAdapter
  })
  const authApi = axios.create({
    timeout: 30000,
    withCredentials,
    adapter: options.authAdapter
  })

  let refreshPromise: Promise<void> | null = null
  let sessionExpiredHandler: () => void = () => undefined
  let sessionExpiredNotified = false

  function setSessionExpiredHandler(handler: () => void): void {
    sessionExpiredHandler = handler
  }

  function notifySessionExpired(): void {
    if (sessionExpiredNotified) return
    sessionExpiredNotified = true
    sessionExpiredHandler()
  }

  async function rotateSessionIfNeeded(): Promise<void> {
    try {
      await authApi.get('/api/auth/me')
      return
    } catch (error: unknown) {
      if (!isSessionRejection(error)) throw error
    }

    await authApi.post('/api/auth/refresh', {})
  }

  function withCrossTabRefreshLock(operation: () => Promise<void>): Promise<void> {
    if (typeof navigator === 'undefined' || !navigator.locks) return operation()
    return navigator.locks
      .request(REFRESH_LOCK_NAME, operation)
      .then(() => undefined)
  }

  function refreshSession(): Promise<void> {
    if (refreshPromise) return refreshPromise

    refreshPromise = withCrossTabRefreshLock(rotateSessionIfNeeded)
      .then(() => undefined)
      .catch((error: unknown) => {
        if (isSessionRejection(error)) {
          notifySessionExpired()
        }
        throw error
      })
      .finally(() => {
        refreshPromise = null
      })

    return refreshPromise
  }

  api.interceptors.response.use(
    (response) => {
      sessionExpiredNotified = false
      return response
    },
    async (error: unknown) => {
      if (!axios.isAxiosError(error) || error.response?.status !== 401 || !error.config) {
        return Promise.reject(error)
      }

      const request = error.config as RetryableRequestConfig
      if (request._retry || AUTH_REQUESTS_WITHOUT_REFRESH.has(requestPath(request.url))) {
        if (request._retry) notifySessionExpired()
        return Promise.reject(error)
      }

      request._retry = true
      await refreshSession()
      return api.request(request)
    }
  )

  return { api, refreshSession, setSessionExpiredHandler }
}
