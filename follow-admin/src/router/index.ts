import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'Login',
      component: () => import('@/views/auth/LoginView.vue'),
      meta: { requiresAuth: false }
    },
    {
      path: '/',
      component: () => import('@/layouts/AdminLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        {
          path: '',
          name: 'Dashboard',
          component: () => import('@/views/dashboard/DashboardView.vue')
        },
        {
          path: 'tracks',
          name: 'Tracks',
          component: () => import('@/views/music/TracksView.vue')
        },
        {
          path: 'tracks/imports',
          name: 'MusicImports',
          component: () => import('@/views/music/imports/MusicImportListView.vue'),
          meta: { activeMenu: '/tracks', title: '音乐导入任务' }
        },
        {
          path: 'tracks/imports/new',
          name: 'MusicImportCreate',
          component: () => import('@/views/music/imports/MusicImportCreateView.vue'),
          meta: { activeMenu: '/tracks', title: '创建导入任务' }
        },
        {
          path: 'tracks/imports/:jobId',
          name: 'MusicImportDetail',
          component: () => import('@/views/music/imports/MusicImportDetailView.vue'),
          meta: { activeMenu: '/tracks', title: '导入任务详情' }
        },
        {
          path: 'artists',
          name: 'Artists',
          component: () => import('@/views/music/ArtistsView.vue')
        },
        {
          path: 'albums',
          name: 'Albums',
          component: () => import('@/views/music/AlbumsView.vue')
        },
        {
          path: 'tags',
          name: 'Tags',
          component: () => import('@/views/music/TagsView.vue')
        },
        {
          path: 'users',
          name: 'Users',
          component: () => import('@/views/users/UsersView.vue')
        }
      ]
    }
  ]
})

router.beforeEach(async (to) => {
  const authStore = useAuthStore()

  if (!authStore.isRestored) {
    await authStore.restoreSession()
  }

  if (to.meta.requiresAuth && !authStore.isAuthenticated) {
    return {
      path: '/login',
      query: { redirect: to.fullPath }
    }
  }

  if (to.path === '/login' && authStore.isAuthenticated) {
    return '/'
  }

  return true
})

export default router
