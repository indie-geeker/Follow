import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { useAuthStore } from './stores/auth'
import { setSessionExpiredHandler } from './api'
import { installElementPlus } from './plugins/elementPlus'
import { loadRememberedEmail } from './utils/rememberedAccount'
import './styles/tokens.css'
import './styles/theme.css'
import './styles/admin-components.css'

async function bootstrap(): Promise<void> {
  const app = createApp(App)
  const pinia = createPinia()

  app.use(pinia)
  installElementPlus(app)

  const authStore = useAuthStore(pinia)
  authStore.clearLegacyAuthStorage()
  loadRememberedEmail(localStorage)
  setSessionExpiredHandler(() => {
    authStore.expireSession()
    const currentRoute = router.currentRoute.value
    if (currentRoute.path !== '/login') {
      void router.replace({
        path: '/login',
        query: { redirect: currentRoute.fullPath }
      })
    }
  })

  await authStore.restoreSession()
  app.use(router)
  await router.isReady()
  app.mount('#app')
}

void bootstrap()
