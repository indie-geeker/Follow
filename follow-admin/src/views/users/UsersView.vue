<template>
  <div class="users-view">
    <div class="page-header">
      <h2>用户管理</h2>
    </div>

    <el-card>
      <el-table :data="users" v-loading="loading">
        <el-table-column prop="username" label="用户名" />
        <el-table-column prop="email" label="邮箱" />
        <el-table-column label="角色" width="120">
          <template #default="{ row }">
            <el-tag :type="row.role === 'Admin' ? 'danger' : 'info'">
              {{ row.role }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="playlistCount" label="播放列表" width="100" />
        <el-table-column prop="favoriteCount" label="收藏" width="80" />
        <el-table-column label="操作" width="200">
          <template #default="{ row }">
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
          </template>
        </el-table-column>
      </el-table>

      <el-pagination
        v-model:current-page="pagination.page"
        :page-size="pagination.pageSize"
        :total="pagination.total"
        layout="total, prev, pager, next"
        @current-change="loadUsers"
        style="margin-top: 16px; justify-content: flex-end;"
      />
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
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
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
.page-header h2 { margin: 0; }
</style>
