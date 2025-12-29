<template>
  <div class="dashboard">
    <h2>仪表盘</h2>
    
    <el-row :gutter="20" class="stats-row">
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-icon users"><el-icon><User /></el-icon></div>
          <div class="stat-info">
            <div class="stat-value">{{ stats.totalUsers }}</div>
            <div class="stat-label">用户数</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-icon tracks"><el-icon><Headset /></el-icon></div>
          <div class="stat-info">
            <div class="stat-value">{{ stats.totalTracks }}</div>
            <div class="stat-label">曲目数</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-icon artists"><el-icon><UserFilled /></el-icon></div>
          <div class="stat-info">
            <div class="stat-value">{{ stats.totalArtists }}</div>
            <div class="stat-label">艺术家</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-icon albums"><el-icon><Collection /></el-icon></div>
          <div class="stat-info">
            <div class="stat-value">{{ stats.totalAlbums }}</div>
            <div class="stat-label">专辑</div>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { User, Headset, UserFilled, Collection } from '@element-plus/icons-vue'
import api from '@/api'

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
.dashboard h2 {
  margin-bottom: 24px;
  color: #333;
}

.stats-row {
  margin-bottom: 24px;
}

.stat-card {
  display: flex;
  align-items: center;
  padding: 20px;
}

.stat-card :deep(.el-card__body) {
  display: flex;
  align-items: center;
  gap: 16px;
  width: 100%;
}

.stat-icon {
  width: 56px;
  height: 56px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
  color: #fff;
}

.stat-icon.users { background: linear-gradient(135deg, #667eea, #764ba2); }
.stat-icon.tracks { background: linear-gradient(135deg, #f093fb, #f5576c); }
.stat-icon.artists { background: linear-gradient(135deg, #4facfe, #00f2fe); }
.stat-icon.albums { background: linear-gradient(135deg, #43e97b, #38f9d7); }

.stat-value {
  font-size: 28px;
  font-weight: bold;
  color: #333;
}

.stat-label {
  color: #999;
  font-size: 14px;
}
</style>
