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
          path: 'users',
          name: 'Users',
          component: () => import('@/views/users/UsersView.vue')
        }
      ]
    }
  ]
})

router.beforeEach((to, _from, next) => {
  const authStore = useAuthStore()

  if (to.meta.requiresAuth && !authStore.isAuthenticated) {
    next('/login')
  } else if (to.path === '/login' && authStore.isAuthenticated) {
    next('/')
  } else {
    next()
  }
})

export default router
