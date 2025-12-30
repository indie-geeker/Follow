<template>
  <div class="dashboard">
    <el-row :gutter="24" class="stats-row">
      <el-col :span="6" v-for="(stat, index) in statCards" :key="stat.key">
        <div class="stat-card" :style="{ animationDelay: `${index * 0.1}s` }">
          <div class="stat-icon" :class="stat.key">
            <el-icon><component :is="stat.icon" /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-value">{{ stats[stat.key] }}</div>
            <div class="stat-label">{{ stat.label }}</div>
          </div>
          <div class="stat-bg-icon">
            <el-icon><component :is="stat.icon" /></el-icon>
          </div>
        </div>
      </el-col>
    </el-row>

    <el-row :gutter="24">
      <el-col :span="24">
        <el-card class="welcome-card">
          <div class="welcome-content">
            <div class="welcome-text">
              <h3>欢迎回来！</h3>
              <p>这是 Follow Music 管理后台，您可以在这里管理曲目、艺术家、专辑和用户。</p>
            </div>
            <div class="welcome-illustration">
              <svg viewBox="0 0 200 120" fill="none" xmlns="http://www.w3.org/2000/svg">
                <rect x="20" y="40" width="40" height="60" rx="4" fill="url(#grad1)" opacity="0.8"/>
                <rect x="70" y="20" width="40" height="80" rx="4" fill="url(#grad2)" opacity="0.8"/>
                <rect x="120" y="50" width="40" height="50" rx="4" fill="url(#grad3)" opacity="0.8"/>
                <circle cx="100" cy="15" r="8" fill="#667eea"/>
                <path d="M100 15 L100 100" stroke="#667eea" stroke-width="2" stroke-dasharray="4 4" opacity="0.5"/>
                <defs>
                  <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" style="stop-color:#667eea"/>
                    <stop offset="100%" style="stop-color:#764ba2"/>
                  </linearGradient>
                  <linearGradient id="grad2" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" style="stop-color:#f093fb"/>
                    <stop offset="100%" style="stop-color:#f5576c"/>
                  </linearGradient>
                  <linearGradient id="grad3" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" style="stop-color:#4facfe"/>
                    <stop offset="100%" style="stop-color:#00f2fe"/>
                  </linearGradient>
                </defs>
              </svg>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, markRaw } from 'vue'
import { User, Headset, UserFilled, Collection } from '@element-plus/icons-vue'
import api from '@/api'

const statCards = [
  { key: 'totalUsers', label: '用户数', icon: markRaw(User) },
  { key: 'totalTracks', label: '曲目数', icon: markRaw(Headset) },
  { key: 'totalArtists', label: '艺术家', icon: markRaw(UserFilled) },
  { key: 'totalAlbums', label: '专辑', icon: markRaw(Collection) }
]

const stats = ref({
  totalUsers: 0,
  totalTracks: 0,
  totalArtists: 0,
  totalAlbums: 0,
  totalPlaylists: 0
})

onMounted(async () => {
  try {
    const response = await api.get('/api/admin/dashboard')
    stats.value = response.data
  } catch (error) {
    console.error('Failed to load dashboard stats', error)
  }
})
</script>

<style scoped>
.dashboard {
  animation: fadeIn 0.5s ease;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}

.stats-row {
  margin-bottom: 24px;
}

.stat-card {
  position: relative;
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: var(--radius-lg);
  padding: 24px;
  display: flex;
  align-items: center;
  gap: 16px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
  overflow: hidden;
  animation: slideUp 0.5s ease backwards;
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.stat-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.4);
}

@keyframes slideUp {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}

.stat-icon {
  width: 56px;
  height: 56px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
  color: #fff;
  flex-shrink: 0;
  position: relative;
  z-index: 1;
}

.stat-icon.totalUsers { background: var(--gradient-users); box-shadow: 0 4px 14px rgba(102, 126, 234, 0.35); }
.stat-icon.totalTracks { background: var(--gradient-tracks); box-shadow: 0 4px 14px rgba(240, 147, 251, 0.35); }
.stat-icon.totalArtists { background: var(--gradient-artists); box-shadow: 0 4px 14px rgba(79, 172, 254, 0.35); }
.stat-icon.totalAlbums { background: var(--gradient-albums); box-shadow: 0 4px 14px rgba(67, 233, 123, 0.35); }

.stat-info {
  flex: 1;
  position: relative;
  z-index: 1;
}

.stat-value {
  font-size: 32px;
  font-weight: 700;
  color: #ffffff;
  line-height: 1.2;
  text-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
}

.stat-label {
  color: rgba(255, 255, 255, 0.7);
  font-size: 14px;
  margin-top: 4px;
}

.stat-bg-icon {
  position: absolute;
  right: -10px;
  bottom: -10px;
  font-size: 80px;
  color: rgba(255, 255, 255, 0.05);
  z-index: 0;
}

/* Welcome Card */
.welcome-card {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: var(--radius-lg);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
}

.welcome-card :deep(.el-card__body) {
  padding: 0;
}

.welcome-content {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 32px;
  background: linear-gradient(135deg, rgba(102, 126, 234, 0.1) 0%, rgba(118, 75, 162, 0.1) 100%);
  border-radius: var(--radius-lg);
}

.welcome-text h3 {
  font-size: 24px;
  font-weight: 700;
  color: #ffffff;
  margin-bottom: 8px;
  text-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
}

.welcome-text p {
  color: rgba(255, 255, 255, 0.7);
  font-size: 15px;
  line-height: 1.6;
  max-width: 400px;
}

.welcome-illustration {
  width: 200px;
  height: 120px;
}

.welcome-illustration svg {
  width: 100%;
  height: 100%;
}
</style>
