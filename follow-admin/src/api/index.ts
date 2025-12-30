import axios from 'axios'
import { useAuthStore } from '@/stores/auth'

const api = axios.create({
    baseURL: import.meta.env.VITE_API_URL || 'http://localhost:5000',
    timeout: 30000
})

api.interceptors.request.use(config => {
    const token = localStorage.getItem('token')
    if (token) {
        config.headers.Authorization = `Bearer ${token}`
    }
    return config
})

api.interceptors.response.use(
    response => response,
    async error => {
        // 登录请求本身返回 401 是正常情况，不需要跳转刷新页面
        const isLoginRequest = error.config?.url?.includes('/api/auth/login')

        if (error.response?.status === 401 && !isLoginRequest) {
            const authStore = useAuthStore()
            authStore.logout()
            window.location.href = '/login'
        }
        return Promise.reject(error)
    }
)

export default api
