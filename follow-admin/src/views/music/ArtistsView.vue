<template>
  <div class="artists-view">
    <div class="page-header">
      <div class="header-left">
        <p class="page-subtitle">管理音乐创作者信息</p>
      </div>
      <el-button type="primary" @click="showDialog()" class="add-btn">
        <el-icon><Plus /></el-icon>
        添加艺术家
      </el-button>
    </div>

    <el-card class="content-card">
      <el-table :data="artists" v-loading="loading" class="custom-table">
        <el-table-column prop="name" label="名称" min-width="150">
          <template #default="{ row }">
            <div class="artist-cell">
              <div class="artist-avatar">
                {{ row.name?.charAt(0)?.toUpperCase() }}
              </div>
              <span class="artist-name">{{ row.name }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="bio" label="简介" show-overflow-tooltip>
          <template #default="{ row }">
            <span class="bio-text">{{ row.bio || '暂无简介' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150">
          <template #default="{ row }">
            <div class="action-buttons">
              <el-button link type="primary" @click="showDialog(row)">编辑</el-button>
              <el-button link type="danger" @click="deleteArtist(row.id)">删除</el-button>
            </div>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="form.id ? '编辑艺术家' : '添加艺术家'" width="500px">
      <el-form :model="form" label-width="80px">
        <el-form-item label="名称" required>
          <el-input v-model="form.name" placeholder="请输入艺术家名称" />
        </el-form-item>
        <el-form-item label="简介">
          <el-input v-model="form.bio" type="textarea" :rows="4" placeholder="请输入艺术家简介" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveArtist">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus } from '@element-plus/icons-vue'
import api from '@/api'

const loading = ref(false)
const artists = ref<any[]>([])
const dialogVisible = ref(false)
const form = reactive({ id: '', name: '', bio: '' })

async function loadArtists() {
  loading.value = true
  try {
    const response = await api.get('/api/artists')
    artists.value = response.data
  } finally {
    loading.value = false
  }
}

function showDialog(artist?: any) {
  form.id = artist?.id || ''
  form.name = artist?.name || ''
  form.bio = artist?.bio || ''
  dialogVisible.value = true
}

async function saveArtist() {
  try {
    if (form.id) {
      await api.put(`/api/artists/${form.id}`, { name: form.name, bio: form.bio })
    } else {
      await api.post('/api/artists', { name: form.name, bio: form.bio })
    }
    ElMessage.success('保存成功')
    dialogVisible.value = false
    loadArtists()
  } catch {
    ElMessage.error('保存失败')
  }
}

async function deleteArtist(id: string) {
  try {
    await ElMessageBox.confirm('确定删除此艺术家？', '确认')
    await api.delete(`/api/artists/${id}`)
    ElMessage.success('删除成功')
    loadArtists()
  } catch (e: any) {
    if (e !== 'cancel') ElMessage.error('删除失败')
  }
}

onMounted(loadArtists)
</script>

<style scoped>
.artists-view {
  animation: fadeIn 0.5s ease;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

.page-subtitle {
  color: rgba(255, 255, 255, 0.7);
  font-size: 14px;
  margin: 0;
}

.add-btn {
  padding: 12px 20px;
  font-weight: 600;
}

.content-card {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: var(--radius-lg);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
}

.content-card :deep(.el-card__body) {
  padding: 0;
}

/* Table dark mode styling */
.content-card :deep(.el-table) {
  background: transparent;
}

.content-card :deep(.el-table tr) {
  background: transparent;
}

.content-card :deep(.el-table th.el-table__cell) {
  background: rgba(255, 255, 255, 0.05) !important;
  color: rgba(255, 255, 255, 0.9) !important;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.content-card :deep(.el-table td.el-table__cell) {
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  color: rgba(255, 255, 255, 0.85);
}

.content-card :deep(.el-table__body tr:hover > td) {
  background: rgba(255, 255, 255, 0.08) !important;
}

.artist-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}

.artist-avatar {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: var(--gradient-artists);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 16px;
  box-shadow: 0 2px 8px rgba(79, 172, 254, 0.3);
}

.artist-name {
  font-weight: 600;
  color: #ffffff;
}

.bio-text {
  color: rgba(255, 255, 255, 0.65);
}

.action-buttons {
  display: flex;
  gap: 8px;
}
</style>
