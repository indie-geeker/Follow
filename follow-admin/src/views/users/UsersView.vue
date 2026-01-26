<template>
  <div class="users-view">
    <div class="page-header">
      <div class="header-left">
        <p class="page-subtitle">管理系统用户</p>
      </div>
    </div>

    <el-card class="content-card">
      <el-table :data="users" v-loading="loading" class="custom-table">
        <el-table-column prop="username" label="用户名" min-width="150">
          <template #default="{ row }">
            <div class="user-cell">
              <div class="user-avatar" :class="{ admin: row.role === 'Admin' }">
                {{ row.username?.charAt(0)?.toUpperCase() }}
              </div>
              <span class="user-name">{{ row.username }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="email" label="邮箱" min-width="180">
          <template #default="{ row }">
            <span class="email-text">{{ row.email }}</span>
          </template>
        </el-table-column>
        <el-table-column label="角色" width="120">
          <template #default="{ row }">
            <el-tag :type="row.role === 'Admin' ? 'danger' : 'info'" class="role-tag">
              {{ row.role === 'Admin' ? '管理员' : '用户' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="playlistCount" label="播放列表" width="100" align="center">
          <template #default="{ row }">
            <span class="count-badge">{{ row.playlistCount || 0 }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="favoriteCount" label="收藏" width="80" align="center">
          <template #default="{ row }">
            <span class="count-badge">{{ row.favoriteCount || 0 }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200">
          <template #default="{ row }">
            <div class="action-buttons">
              <el-button 
                link 
                type="primary" 
                @click="toggleRole(row)"
                :disabled="row.role === 'Admin'"
              >
                {{ row.role === 'Admin' ? '管理员' : '设为管理员' }}
              </el-button>
              <el-button 
                link 
                type="danger" 
                @click="deleteUser(row.id)"
                :disabled="row.role === 'Admin'"
              >
                删除
              </el-button>
            </div>
          </template>
        </el-table-column>
      </el-table>

      <el-pagination
        v-model:current-page="pagination.page"
        :page-size="pagination.pageSize"
        :total="pagination.total"
        layout="total, prev, pager, next"
        @current-change="loadUsers"
        class="pagination"
      />
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Star } from '@element-plus/icons-vue'
import api from '@/api'

const loading = ref(false)
const users = ref<any[]>([])
const pagination = reactive({ page: 1, pageSize: 20, total: 0 })

async function loadUsers() {
  loading.value = true
  try {
    const response = await api.get('/api/admin/users', {
      params: { page: pagination.page, pageSize: pagination.pageSize }
    })
    users.value = response.data.users
    pagination.total = response.data.totalCount
  } finally {
    loading.value = false
  }
}

async function toggleRole(user: any) {
  try {
    await ElMessageBox.confirm(`确定将 ${user.username} 设为管理员？`, '确认')
    await api.put(`/api/admin/users/${user.id}/role`, { role: 'Admin' })
    ElMessage.success('更新成功')
    loadUsers()
  } catch (e: any) {
    if (e !== 'cancel') ElMessage.error('更新失败')
  }
}

async function deleteUser(id: string) {
  try {
    await ElMessageBox.confirm('确定删除此用户？', '确认')
    await api.delete(`/api/admin/users/${id}`)
    ElMessage.success('删除成功')
    loadUsers()
  } catch (e: any) {
    if (e !== 'cancel') ElMessage.error(e.response?.data?.error || '删除失败')
  }
}

onMounted(loadUsers)
</script>

<style scoped>
.users-view {
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

.user-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}

.user-avatar {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: var(--gradient-users);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 16px;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
}

.user-avatar.admin {
  background: linear-gradient(135deg, #f5576c 0%, #f093fb 100%);
  box-shadow: 0 2px 8px rgba(245, 87, 108, 0.3);
}

.user-name {
  font-weight: 600;
  color: #ffffff;
}

.email-text {
  color: rgba(255, 255, 255, 0.65);
}

.role-tag {
  font-weight: 500;
}

.count-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  height: 24px;
  padding: 0 8px;
  background: rgba(102, 126, 234, 0.1);
  color: var(--primary-color);
  border-radius: 12px;
  font-weight: 600;
  font-size: 13px;
}

.action-buttons {
  display: flex;
  gap: 8px;
}

.pagination {
  padding: 16px 20px;
  justify-content: flex-end;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
}
</style>
