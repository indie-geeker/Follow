<template>
  <div class="albums-view">
    <div class="page-header">
      <h2>专辑</h2>
      <el-button type="primary" @click="showDialog()">添加专辑</el-button>
    </div>

    <el-card>
      <el-table :data="albums" v-loading="loading">
        <el-table-column prop="title" label="标题" />
        <el-table-column label="艺术家">
          <template #default="{ row }">{{ row.artist?.name || '-' }}</template>
        </el-table-column>
        <el-table-column prop="year" label="年份" width="100" />
        <el-table-column label="操作" width="150">
          <template #default="{ row }">
            <el-button link type="primary" @click="showDialog(row)">编辑</el-button>
            <el-button link type="danger" @click="deleteAlbum(row.id)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="form.id ? '编辑专辑' : '添加专辑'" width="500px">
      <el-form :model="form" label-width="80px">
        <el-form-item label="标题" required>
          <el-input v-model="form.title" />
        </el-form-item>
        <el-form-item label="年份">
          <el-input-number v-model="form.year" :min="1900" :max="2100" />
        </el-form-item>
        <el-form-item label="艺术家">
          <el-select v-model="form.artistId" clearable placeholder="选择艺术家">
            <el-option v-for="a in artists" :key="a.id" :label="a.name" :value="a.id" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveAlbum">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import api from '@/api'

const loading = ref(false)
const albums = ref<any[]>([])
const artists = ref<any[]>([])
const dialogVisible = ref(false)
const form = reactive({ id: '', title: '', year: new Date().getFullYear(), artistId: '' })

async function loadAlbums() {
  loading.value = true
  try {
    const [albumsRes, artistsRes] = await Promise.all([
      api.get('/api/albums'),
      api.get('/api/artists')
    ])
    albums.value = albumsRes.data
    artists.value = artistsRes.data
  } finally {
    loading.value = false
  }
}

function showDialog(album?: any) {
  form.id = album?.id || ''
  form.title = album?.title || ''
  form.year = album?.year || new Date().getFullYear()
  form.artistId = album?.artist?.id || ''
  dialogVisible.value = true
}

async function saveAlbum() {
  try {
    const data = { title: form.title, year: form.year, artistId: form.artistId || null }
    if (form.id) {
      await api.put(`/api/albums/${form.id}`, data)
    } else {
      await api.post('/api/albums', data)
    }
    ElMessage.success('保存成功')
    dialogVisible.value = false
    loadAlbums()
  } catch {
    ElMessage.error('保存失败')
  }
}

async function deleteAlbum(id: string) {
  try {
    await ElMessageBox.confirm('确定删除？', '确认')
    await api.delete(`/api/albums/${id}`)
    ElMessage.success('删除成功')
    loadAlbums()
  } catch (e: any) {
    if (e !== 'cancel') ElMessage.error('删除失败')
  }
}

onMounted(loadAlbums)
</script>

<style scoped>
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
.page-header h2 { margin: 0; }
</style>
