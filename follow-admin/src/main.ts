import { createApp } from 'vue'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import App from './App.vue'
import router from './router'
import { useAuthStore } from './stores/auth'

const app = createApp(App)

app.use(createPinia())
app.use(ElementPlus)
app.use(router)

// Fetch user on app start
const authStore = useAuthStore()
if (authStore.token) {
    authStore.fetchUser()
}

app.mount('#app')
