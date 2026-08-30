import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import api from '@/api'

interface User {
  id: string
  username: string
  email: string
  role: string
  avatarUrl?: string
}

interface AuthPayload {
  user: User
}

interface ApiEnvelope<T> {
  code: number
  message?: string
  data: T
}

type AuthStatus = 'unknown' | 'authenticated' | 'anonymous'

function readAuthPayload(response: { data: ApiEnvelope<AuthPayload> }): AuthPayload {
  if (response.data.code !== 0 || !response.data.data?.user) {
    throw new Error(response.data.message || '认证失败')
  }
  return response.data.data
}

function readUser(response: { data: ApiEnvelope<User> }): User {
  if (response.data.code !== 0 || !response.data.data) {
    throw new Error(response.data.message || '会话恢复失败')
  }
  return response.data.data
}

export const useAuthStore = defineStore('auth', () => {
  const status = ref<AuthStatus>('unknown')
  const user = ref<User | null>(null)
  let restorePromise: Promise<boolean> | null = null

  const isRestored = computed(() => status.value !== 'unknown')
  const isAuthenticated = computed(
    () => status.value === 'authenticated' && user.value?.role === 'Admin'
  )
  const isAdmin = computed(() => user.value?.role === 'Admin')

  function clearLegacyAuthStorage(): void {
    localStorage.removeItem('token')
    localStorage.removeItem('refreshToken')
  }

  function clearSession(): void {
    user.value = null
    status.value = 'anonymous'
  }

  async function revokeNonAdminSession(): Promise<void> {
    try {
      await api.post('/api/auth/logout')
    } catch {
      // Server-side role policy still prevents this cookie session from using the admin API.
    } finally {
      clearSession()
    }
  }

  async function login(email: string, password: string): Promise<void> {
    const response = await api.post<ApiEnvelope<AuthPayload>>('/api/auth/login', {
      email,
      password,
      tokenTransport: 'cookie'
    })
    const payload = readAuthPayload(response)

    if (payload.user.role !== 'Admin') {
      await revokeNonAdminSession()
      throw new Error('仅管理员可访问')
    }

    user.value = payload.user
    status.value = 'authenticated'
  }

  async function restoreSession(): Promise<boolean> {
    if (isRestored.value) return isAuthenticated.value
    if (restorePromise) return restorePromise

    restorePromise = (async () => {
      try {
        const response = await api.get<ApiEnvelope<User>>('/api/auth/me')
        const restoredUser = readUser(response)

        if (restoredUser.role !== 'Admin') {
          await revokeNonAdminSession()
          return false
        }

        user.value = restoredUser
        status.value = 'authenticated'
        return true
      } catch {
        clearSession()
        return false
      }
    })().finally(() => {
      restorePromise = null
    })

    return restorePromise
  }

  async function logout(): Promise<void> {
    await api.post('/api/auth/logout')
    clearSession()
  }

  function expireSession(): void {
    clearSession()
  }

  return {
    status,
    user,
    isRestored,
    isAuthenticated,
    isAdmin,
    clearLegacyAuthStorage,
    login,
    restoreSession,
    logout,
    expireSession
  }
})
