import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '@/api'

interface User {
    id: string
    username: string
    email: string
    role: string
    avatarUrl?: string
}

export const useAuthStore = defineStore('auth', () => {
    const token = ref<string | null>(localStorage.getItem('token'))
    const refreshToken = ref<string | null>(localStorage.getItem('refreshToken'))
    const user = ref<User | null>(null)

    const isAuthenticated = computed(() => !!token.value)
    const isAdmin = computed(() => user.value?.role === 'Admin')

    async function login(email: string, password: string) {
        const response = await api.post('/api/auth/login', { email, password })
        const res = response.data

        if (res.code !== 0) {
            throw new Error(res.message || 'Login failed')
        }

        const data = res.data
        token.value = data.accessToken
        refreshToken.value = data.refreshToken
        user.value = data.user

        localStorage.setItem('token', token.value!)
        localStorage.setItem('refreshToken', refreshToken.value!)
    }

    async function fetchUser() {
        if (!token.value) return
        try {
            const response = await api.get('/api/auth/me')
            const res = response.data
            if (res.code === 0) {
                user.value = res.data
            } else {
                throw new Error(res.message)
            }
        } catch {
            logout()
        }
    }

    function logout() {
        token.value = null
        refreshToken.value = null
        user.value = null
        localStorage.removeItem('token')
        localStorage.removeItem('refreshToken')
    }

    return {
        token,
        refreshToken,
        user,
        isAuthenticated,
        isAdmin,
        login,
        fetchUser,
        logout
    }
})
