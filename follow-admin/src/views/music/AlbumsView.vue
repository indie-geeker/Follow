<template>
  <div class="albums-view">
    <div class="page-header">
      <div class="header-left">
        <p class="page-subtitle">管理音乐专辑</p>
      </div>
      <el-button type="primary" @click="showDialog()" class="add-btn">
        <el-icon><Plus /></el-icon>
        添加专辑
      </el-button>
    </div>

    <el-card class="content-card">
      <el-table
        :data="albums"
        v-loading="loading"
        empty-text="暂无专辑"
        class="custom-table"
      >
        <el-table-column prop="title" label="标题" min-width="150">
          <template #default="{ row }">
            <div class="album-cell">
              <el-image
                v-if="toCoverProxyUrl(row.coverUrl)"
                :src="toCoverProxyUrl(row.coverUrl)"
                class="album-cover"
                fit="cover"
              />
              <div v-else class="album-cover">
                <el-icon><Collection /></el-icon>
              </div>
              <span class="album-title">{{ row.title }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="艺术家" min-width="120">
          <template #default="{ row }">
            <span class="artist-name">{{ row.artist?.name || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="year" label="年份" width="100">
          <template #default="{ row }">
            <span :class="{ 'empty-value': !row.year }">{{ formatOptionalYear(row.year) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150">
          <template #default="{ row }">
            <div class="action-buttons">
              <el-button link type="primary" @click="showDialog(row)">编辑</el-button>
              <el-button link type="danger" @click="deleteAlbum(row.id)">删除</el-button>
            </div>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="form.id ? '编辑专辑' : '添加专辑'" width="500px">
      <el-form :model="form" label-width="80px">
        <el-form-item label="标题" required>
          <el-input v-model="form.title" placeholder="请输入专辑标题" />
        </el-form-item>
        <el-form-item label="年份">
          <el-input-number v-model="form.year" :min="1900" :max="2100" />
        </el-form-item>

        <el-form-item label="封面">
          <div class="cover-edit-area">
             <div class="upload-section" v-if="form.id">
               <el-image
                v-if="toCoverProxyUrl(form.coverUrl)"
                :src="toCoverProxyUrl(form.coverUrl)"
                class="edit-preview"
                fit="cover"
               />
               <el-upload
                 :http-request="uploadAlbumCover"
                 :show-file-list="false"
                 :on-success="handleCoverUpload"
                 accept=".jpg,.jpeg,.png,.webp,.gif"
               >
                 <el-button type="primary" size="small">上传封面文件</el-button>
               </el-upload>
             </div>
             <div v-else class="upload-tip">
               保存后可上传本地图片
             </div>
          </div>
        </el-form-item>
        <el-form-item label="艺术家">
          <el-select v-model="form.artistId" clearable placeholder="选择艺术家" style="width: 100%">
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
import { ref, reactive, onMounted, computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Collection } from '@element-plus/icons-vue'
import api from '@/api'
import { createApiUpload } from '@/api/upload'
import { normalizeCoverObjectKey, toCoverProxyUrl } from '@/utils/coverUrl'
import { formatOptionalYear, normalizeOptionalYear } from '@/utils/display'

interface AlbumForm {
  id: string
  title: string
  year: number | undefined
  artistId: string
  coverUrl: string
}

const loading = ref(false)
const albums = ref<any[]>([])
const artists = ref<any[]>([])
const dialogVisible = ref(false)
const form = reactive<AlbumForm>({
  id: '',
  title: '',
  year: new Date().getFullYear(),
  artistId: '',
  coverUrl: ''
})

const coverUploadUrl = computed(() => `/api/albums/${form.id}/cover`)
const uploadAlbumCover = createApiUpload(() => coverUploadUrl.value)

async function loadAlbums() {
  loading.value = true
  try {
    const [albumsRes, artistsRes] = await Promise.all([
      api.get('/api/albums'),
      api.get('/api/artists')
    ])
    albums.value = albumsRes.data
    artists.value = artistsRes.data
  } catch {
    ElMessage.error('加载专辑失败')
  } finally {
    loading.value = false
  }
}

function showDialog(album?: any) {
  form.id = album?.id || ''
  form.title = album?.title || ''
  form.year = album ? album?.year ?? undefined : new Date().getFullYear()
  form.artistId = album?.artist?.id || ''
  form.coverUrl = normalizeCoverObjectKey(album?.coverUrl) ?? ''
  dialogVisible.value = true
}

function handleCoverUpload(response: any) {
  const coverObjectKey = normalizeCoverObjectKey(response.coverUrl)
  if (coverObjectKey) {
    form.coverUrl = coverObjectKey
    ElMessage.success('封面上传成功')
  }
}

async function saveAlbum() {
  try {
    const data = {
      title: form.title,
      year: normalizeOptionalYear(form.year),
      artistId: form.artistId || null
    }
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
    await ElMessageBox.confirm('确定删除此专辑？', '确认')
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
.albums-view {
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

.album-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}

.album-cover {
  width: 40px;
  height: 40px;
  border-radius: 8px;
  background: var(--gradient-albums);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  box-shadow: 0 2px 8px rgba(67, 233, 123, 0.3);
}

.album-title {
  font-weight: 600;
  color: #ffffff;
}

.artist-name {
  color: rgba(255, 255, 255, 0.65);
}

.empty-value {
  color: rgba(255, 255, 255, 0.45);
}

.action-buttons {
  display: flex;
  gap: 8px;
}

.cover-edit-area {
  width: 100%;
}

.upload-section {
  display: flex;
  align-items: center;
  gap: 12px;
}

.edit-preview {
  width: 60px;
  height: 60px;
  border-radius: 4px;
  border: 1px solid rgba(255,255,255,0.1);
}

.upload-tip {
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
}
</style>
