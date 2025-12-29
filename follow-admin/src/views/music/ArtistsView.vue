<template>
  <div class="artists-view">
    <div class="page-header">
      <h2>艺术家</h2>
      <el-button type="primary" @click="showDialog()">添加艺术家</el-button>
    </div>

    <el-card>
      <el-table :data="artists" v-loading="loading">
        <el-table-column prop="name" label="名称" />
        <el-table-column prop="bio" label="简介" show-overflow-tooltip />
        <el-table-column label="操作" width="150">
          <template #default="{ row }">
            <el-button link type="primary" @click="showDialog(row)">编辑</el-button>
            <el-button link type="danger" @click="deleteArtist(row.id)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="form.id ? '编辑艺术家' : '添加艺术家'" width="500px">
      <el-form :model="form" label-width="80px">
        <el-form-item label="名称" required>
          <el-input v-model="form.name" />
        </el-form-item>
        <el-form-item label="简介">
          <el-input v-model="form.bio" type="textarea" :rows="3" />
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
    await ElMessageBox.confirm('确定删除？', '确认')
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
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}
.page-header h2 { margin: 0; }
</style>
