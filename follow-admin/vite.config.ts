import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, '.', '')
  const apiProxyTarget = env.FOLLOW_API_PROXY_TARGET || 'http://localhost:5050'

  return {
    plugins: [vue()],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url))
      }
    },
    server: {
      port: 3000,
      proxy: {
        '/api': {
          target: apiProxyTarget,
          changeOrigin: true
        }
      }
    },
    build: {
      rollupOptions: {
        output: {
          manualChunks(id) {
            if (id.includes('/node_modules/element-plus/') || id.includes('/node_modules/@element-plus/')) {
              return 'element-plus'
            }

            if (
              id.includes('/node_modules/vue/') ||
              id.includes('/node_modules/@vue/') ||
              id.includes('/node_modules/vue-router/') ||
              id.includes('/node_modules/pinia/')
            ) {
              return 'vue-vendor'
            }

            if (id.includes('/node_modules/axios/')) {
              return 'http-vendor'
            }
          }
        }
      }
    }
  }
})
