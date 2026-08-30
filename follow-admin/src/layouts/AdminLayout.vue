<template>
  <el-container class="admin-layout">
    <!-- Animated background circles -->
    <div class="bg-circles">
      <div
        v-for="index in 4"
        :key="index"
        class="circle"
        :class="`circle-${index}`"
      ></div>
    </div>

    <button
      v-if="mobileNavOpen"
      type="button"
      class="sidebar-backdrop"
      aria-label="关闭导航菜单"
      @click="closeMobileNav"
    ></button>

    <el-aside
      id="admin-sidebar"
      width="240px"
      class="sidebar"
      :class="{ 'is-mobile-open': mobileNavOpen }"
      aria-label="管理后台主导航"
    >
      <div class="logo">
        <div class="logo-icon">
          <el-icon><Headset /></el-icon>
        </div>
        <span class="logo-text">Follow Admin</span>
      </div>
      <el-menu
        :default-active="activeMenu"
        router
        class="sidebar-menu"
        @select="closeMobileNav"
      >
        <el-menu-item index="/">
          <el-icon><DataAnalysis /></el-icon>
          <span>仪表盘</span>
        </el-menu-item>
        <el-menu-item index="/tracks">
          <el-icon><Headset /></el-icon>
          <span>曲目管理</span>
        </el-menu-item>
        <el-menu-item index="/artists">
          <el-icon><User /></el-icon>
          <span>艺术家</span>
        </el-menu-item>
        <el-menu-item index="/albums">
          <el-icon><Collection /></el-icon>
          <span>专辑</span>
        </el-menu-item>
        <el-menu-item index="/tags">
          <el-icon><PriceTag /></el-icon>
          <span>标签管理</span>
        </el-menu-item>
        <el-menu-item index="/users">
          <el-icon><UserFilled /></el-icon>
          <span>用户管理</span>
        </el-menu-item>
      </el-menu>
      
      <div class="sidebar-footer">
        <span>© 2026 Follow Music</span>
      </div>
    </el-aside>
    
    <el-container class="main-container">
      <el-header class="header">
        <div class="header-left">
          <el-button
            text
            class="mobile-menu-button"
            aria-label="打开导航菜单"
            aria-controls="admin-sidebar"
            :aria-expanded="mobileNavOpen"
            @click="mobileNavOpen = true"
          >
            <el-icon><Expand /></el-icon>
          </el-button>
          <h3 class="page-title">{{ pageTitle }}</h3>
        </div>
        <div class="header-right">
          <el-dropdown @command="handleCommand">
            <div class="user-info">
              <el-avatar :size="36" class="user-avatar">
                {{ authStore.user?.username?.charAt(0)?.toUpperCase() }}
              </el-avatar>
              <div class="user-details">
                <span class="username">{{ authStore.user?.username }}</span>
                <span class="user-role">管理员</span>
              </div>
              <el-icon class="dropdown-icon"><ArrowDown /></el-icon>
            </div>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="logout">
                  <el-icon><SwitchButton /></el-icon>
                  退出登录
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>

      <el-main class="main-content">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useAuthStore } from '@/stores/auth'
import { 
  DataAnalysis, 
  Headset, 
  User, 
  Collection, 
  UserFilled,
  ArrowDown,
  SwitchButton,
  PriceTag,
  Expand
} from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const mobileNavOpen = ref(false)

const activeMenu = computed(() => (
  typeof route.meta.activeMenu === 'string' ? route.meta.activeMenu : route.path
))

const pageTitle = computed(() => {
  if (typeof route.meta.title === 'string') return route.meta.title

  const titles: Record<string, string> = {
    '/': '仪表盘',
    '/tracks': '曲目管理',
    '/artists': '艺术家',
    '/albums': '专辑',
    '/tags': '标签管理',
    '/users': '用户管理'
  }
  return titles[route.path] || '管理后台'
})

async function handleCommand(command: string) {
  if (command === 'logout') {
    try {
      await authStore.logout()
      await router.push('/login')
    } catch {
      ElMessage.error('退出失败，请检查网络后重试')
    }
  }
}

function closeMobileNav() {
  mobileNavOpen.value = false
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') {
    closeMobileNav()
  }
}

watch(() => route.path, closeMobileNav)

onMounted(() => {
  window.addEventListener('keydown', handleKeydown)
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', handleKeydown)
})
</script>

<style scoped>
.admin-layout {
  height: 100vh;
  overflow: hidden;
  background: linear-gradient(-45deg, #1a1a2e, #16213e, #0f3460, #533483);
  background-size: 400% 400%;
  animation: gradientShift 15s ease infinite;
  position: relative;
}

@keyframes gradientShift {
  0% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
  100% { background-position: 0% 50%; }
}

/* Floating background circles */
.bg-circles {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
  z-index: 0;
  pointer-events: none;
}

.circle {
  position: absolute;
  border-radius: 50%;
  background: linear-gradient(135deg, rgba(102, 126, 234, 0.3), rgba(118, 75, 162, 0.3));
  filter: blur(40px);
  will-change: transform;
  animation: adminCircleDrift 30s ease-in-out infinite;
}

@keyframes adminCircleDrift {
  0%, 100% { transform: translate3d(0, 0, 0) rotate(0deg) scale(1); }
  33% { transform: translate3d(16vw, -10vh, 0) rotate(120deg) scale(1.08); }
  66% { transform: translate3d(-10vw, 14vh, 0) rotate(240deg) scale(0.94); }
}

.circle-1 {
  width: 400px;
  height: 400px;
  top: -100px;
  left: -100px;
}

.circle-2 {
  width: 300px;
  height: 300px;
  top: 50%;
  right: -50px;
  background: linear-gradient(135deg, rgba(236, 72, 153, 0.25), rgba(239, 68, 68, 0.25));
  animation-duration: 34s;
  animation-delay: -8s;
}

.circle-3 {
  width: 250px;
  height: 250px;
  bottom: -50px;
  left: 30%;
  background: linear-gradient(135deg, rgba(34, 211, 238, 0.25), rgba(59, 130, 246, 0.25));
  animation-duration: 28s;
  animation-delay: -16s;
}

.circle-4 {
  width: 350px;
  height: 350px;
  top: 40%;
  left: 10%;
  background: linear-gradient(135deg, rgba(168, 85, 247, 0.2), rgba(236, 72, 153, 0.2));
  animation-duration: 38s;
  animation-delay: -24s;
}

.sidebar-backdrop {
  display: none;
}

/* Sidebar */
.sidebar {
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  display: flex;
  flex-direction: column;
  border-right: 1px solid rgba(255, 255, 255, 0.12);
  overflow: hidden;
  box-shadow: 4px 0 32px rgba(0, 0, 0, 0.3);
  position: relative;
  z-index: 2;
}

.logo {
  height: 72px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  background: transparent;
  padding: 16px 0;
}

.logo-icon {
  width: 48px;
  height: 48px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 22px;
  color: #fff;
  box-shadow: 0 6px 20px rgba(102, 126, 234, 0.5);
  animation: pulse 2s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.05); }
}

.logo-text {
  color: #fff;
  font-size: 20px;
  font-weight: 700;
  letter-spacing: 1px;
  text-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
}

/* Sidebar Menu */
.sidebar-menu {
  flex: 1;
  border: none;
  background: transparent;
  padding: 16px 12px;
  overflow-y: auto;
}

.sidebar-menu :deep(.el-menu-item) {
  height: 48px;
  line-height: 48px;
  margin-bottom: 6px;
  border: 1px solid transparent;
  border-radius: 12px;
  color: rgba(255, 255, 255, 0.7);
  background: transparent;
  transition:
    color 0.3s ease,
    background-color 0.3s ease,
    box-shadow 0.3s ease,
    transform 0.3s ease;
}

.sidebar-menu :deep(.el-menu-item:hover) {
  background: rgba(255, 255, 255, 0.1);
  border-color: rgba(255, 255, 255, 0.2);
  color: #fff;
  transform: translateX(2px);
}

.sidebar-menu :deep(.el-menu-item.is-active) {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-color: transparent;
  color: #fff;
  box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
  transform: translateX(4px);
}

.sidebar-menu :deep(.el-menu-item:focus-visible) {
  outline: 2px solid rgba(255, 255, 255, 0.9);
  outline-offset: -2px;
}

.sidebar-menu :deep(.el-menu-item .el-icon) {
  font-size: 18px;
  margin-right: 10px;
}

.sidebar-footer {
  padding: 20px 16px;
  text-align: center;
  color: rgba(255, 255, 255, 0.4);
  font-size: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
  background: transparent;
}

/* Main Container */
.main-container {
  display: flex;
  flex-direction: column;
  background: transparent;
  overflow: hidden;
  position: relative;
  flex: 1;
}

/* Header */
.header {
  height: 72px;
  background: rgba(255, 255, 255, 0.08);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: none;
  border-bottom: 1px solid rgba(255, 255, 255, 0.12);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
  position: relative;
  z-index: 1;
}

.header-left {
  display: flex;
  align-items: center;
}

.mobile-menu-button {
  display: none;
  width: 44px;
  height: 44px;
  margin-right: 8px;
  color: #fff;
  font-size: 22px;
}

.page-title {
  font-size: 20px;
  font-weight: 600;
  color: #ffffff;
  margin: 0;
  text-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
}

.header-right {
  display: flex;
  align-items: center;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
  padding: 8px 12px;
  border-radius: 12px;
  transition: all 0.3s ease;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.1);
}

.user-info:hover {
  background: rgba(255, 255, 255, 0.12);
  border-color: rgba(255, 255, 255, 0.2);
}

.user-avatar {
  background: var(--primary-gradient);
  color: #fff;
  font-weight: 600;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
}

.user-details {
  display: flex;
  flex-direction: column;
}

.username {
  font-weight: 600;
  color: #ffffff;
  font-size: 14px;
  line-height: 1.3;
}

.user-role {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.6);
  line-height: 1.3;
}

.dropdown-icon {
  color: rgba(255, 255, 255, 0.6);
  font-size: 12px;
}

/* Main Content */
.main-content {
  flex: 1;
  padding: 24px;
  overflow-y: auto;
  background: transparent;
  position: relative;
  z-index: 1;
}

@media (max-width: 1023px) {
  .sidebar {
    width: 72px !important;
    transition: width var(--transition-normal), transform var(--transition-normal);
  }

  .logo {
    gap: 0;
  }

  .logo-icon {
    width: 44px;
    height: 44px;
  }

  .logo-text,
  .sidebar-menu :deep(.el-menu-item span),
  .sidebar-footer {
    display: none;
  }

  .sidebar-menu {
    padding: 16px 8px;
  }

  .sidebar-menu :deep(.el-menu-item) {
    justify-content: center;
    padding: 0 !important;
  }

  .sidebar-menu :deep(.el-menu-item:hover),
  .sidebar-menu :deep(.el-menu-item.is-active) {
    transform: none;
  }

  .sidebar-menu :deep(.el-menu-item .el-icon) {
    margin-right: 0;
  }
}

@media (max-width: 767px) {
  .sidebar {
    position: fixed;
    inset: 0 auto 0 0;
    z-index: 4;
    width: min(280px, 86vw) !important;
    transform: translateX(-105%);
  }

  .sidebar.is-mobile-open {
    transform: translateX(0);
  }

  .sidebar-backdrop {
    position: fixed;
    inset: 0;
    z-index: 3;
    display: block;
    width: 100%;
    height: 100%;
    padding: 0;
    border: 0;
    background: rgba(4, 8, 24, 0.58);
    cursor: default;
  }

  .logo {
    gap: 12px;
  }

  .logo-text,
  .sidebar-menu :deep(.el-menu-item span),
  .sidebar-footer {
    display: initial;
  }

  .sidebar-footer {
    display: block;
  }

  .sidebar-menu {
    padding: 16px 12px;
  }

  .sidebar-menu :deep(.el-menu-item) {
    justify-content: flex-start;
    padding: 0 20px !important;
  }

  .sidebar-menu :deep(.el-menu-item .el-icon) {
    margin-right: 10px;
  }

  .mobile-menu-button {
    display: inline-flex;
  }

  .header {
    padding: 0 12px;
  }

  .main-content {
    padding: 16px;
  }

  .page-title {
    font-size: 18px;
  }

  .user-info {
    gap: 8px;
    padding: 6px 8px;
  }

  .user-role {
    display: none;
  }
}

@media (max-width: 479px) {
  .user-details,
  .dropdown-icon {
    display: none;
  }
}
</style>
