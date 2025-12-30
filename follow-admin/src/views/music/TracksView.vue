<template>
  <div class="tracks-view">
    <div class="page-header">
      <div class="header-left">
        <p class="page-subtitle">管理和上传您的音乐曲目</p>
      </div>
      <el-upload
        :action="uploadUrl"
        :headers="uploadHeaders"
        :on-success="handleUploadSuccess"
        :on-error="handleUploadError"
        :show-file-list="false"
        accept=".mp3,.flac,.wav,.m4a,.aac,.ogg"
      >
        <el-button type="primary" :icon="Upload" class="upload-btn">上传音乐</el-button>
      </el-upload>
    </div>

    <el-card class="content-card">
      <el-table :data="tracks" v-loading="loading" style="width: 100%" class="custom-table">
        <el-table-column label="封面" width="80">
          <template #default="{ row }">
            <el-image
              v-if="row.coverUrl"
              :src="getCoverUrl(row.coverUrl)"
              fit="cover"
              class="track-cover"
            />
            <div v-else class="cover-placeholder">
              <el-icon><Picture /></el-icon>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="title" label="标题" min-width="180">
          <template #default="{ row }">
            <span class="track-title">{{ row.title }}</span>
          </template>
        </el-table-column>
        <el-table-column label="艺术家" width="120">
          <template #default="{ row }">
            <span class="artist-name">{{ row.artist?.name || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="专辑" width="120">
          <template #default="{ row }">
            {{ row.album?.title || '-' }}
          </template>
        </el-table-column>
        <el-table-column label="时长" width="80">
          <template #default="{ row }">
            <span class="duration">{{ formatDuration(row.durationSeconds) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="format" label="格式" width="70">
          <template #default="{ row }">
            <el-tag size="small" class="format-tag">{{ row.format }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="歌词" width="70">
          <template #default="{ row }">
            <el-tag v-if="row.lyricsUrl" type="success" size="small">有</el-tag>
            <el-tag v-else type="info" size="small">无</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <div class="action-buttons">
              <el-button link type="primary" @click="playTrack(row)" class="action-btn play">
                <el-icon><VideoPlay /></el-icon>
              </el-button>
              <el-button link type="primary" @click="editTrack(row)" class="action-btn">
                编辑
              </el-button>
              <el-button link type="danger" @click="deleteTrack(row.id)" class="action-btn">
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
        @current-change="loadTracks"
        class="pagination"
      />
    </el-card>

    <!-- Audio Player -->
    <Transition name="slide-up">
      <div v-if="currentTrack" class="audio-player">
        <div class="player-info">
          <el-image
            v-if="currentTrack.coverUrl"
            :src="getCoverUrl(currentTrack.coverUrl)"
            fit="cover"
            class="player-cover"
          />
          <div v-else class="player-cover-placeholder">
            <el-icon><Headset /></el-icon>
          </div>
          <div class="player-text">
            <div class="player-title">{{ currentTrack.title }}</div>
            <div class="player-artist">{{ currentTrack.artist?.name || '未知艺术家' }}</div>
          </div>
        </div>
        <audio
          ref="audioRef"
          :src="streamUrl"
          controls
          @ended="onAudioEnded"
          class="player-audio"
        />
        <el-button
          :icon="Close"
          circle
          size="small"
          @click="stopPlayback"
          class="player-close"
        />
      </div>
    </Transition>

    <!-- Edit Dialog -->
    <el-dialog v-model="editDialogVisible" title="编辑曲目" width="500px" class="custom-dialog">
      <el-form :model="editForm" label-width="80px">
        <el-form-item label="标题">
          <el-input v-model="editForm.title" />
        </el-form-item>
        <el-form-item label="封面">
          <div class="cover-upload-area">
            <el-image
              v-if="editForm.coverUrl"
              :src="getCoverUrl(editForm.coverUrl)"
              fit="cover"
              class="edit-cover-preview"
            />
            <el-upload
              :action="coverUploadUrl"
              :headers="uploadHeaders"
              :show-file-list="false"
              :on-success="handleCoverUpload"
              accept=".jpg,.jpeg,.png,.webp,.gif"
            >
              <el-button size="small" type="primary">{{ editForm.coverUrl ? '更换封面' : '上传封面' }}</el-button>
            </el-upload>
          </div>
        </el-form-item>
        <el-form-item label="歌词">
          <div class="lyrics-upload-area">
            <el-tag v-if="editForm.lyricsUrl" type="success">已上传歌词</el-tag>
            <el-tag v-else type="info">未上传歌词</el-tag>
            <el-upload
              :action="lyricsUploadUrl"
              :headers="uploadHeaders"
              :show-file-list="false"
              :on-success="handleLyricsUpload"
              accept=".lrc,.txt"
              style="margin-left: 10px;"
            >
              <el-button size="small" type="primary">{{ editForm.lyricsUrl ? '更换歌词' : '上传歌词' }}</el-button>
            </el-upload>
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveTrack">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Upload, VideoPlay, Close, Picture, Headset } from '@element-plus/icons-vue'
import api from '@/api'

const loading = ref(false)
const tracks = ref<any[]>([])
const pagination = reactive({
  page: 1,
  pageSize: 20,
  total: 0
})

// Audio player state
const currentTrack = ref<any>(null)
const audioRef = ref<HTMLAudioElement | null>(null)
const audioBlobUrl = ref<string>('')

// Edit dialog state
const editDialogVisible = ref(false)
const editForm = reactive({
  id: '',
  title: '',
  coverUrl: '',
  lyricsUrl: ''
})

const baseUrl = computed(() => import.meta.env.VITE_API_URL || 'http://localhost:5000')

const uploadUrl = computed(() => `${baseUrl.value}/api/tracks/upload`)

const coverUploadUrl = computed(() => `${baseUrl.value}/api/tracks/${editForm.id}/cover`)

const lyricsUploadUrl = computed(() => `${baseUrl.value}/api/tracks/${editForm.id}/lyrics`)

const streamUrl = computed(() => audioBlobUrl.value)

const uploadHeaders = computed(() => ({
  Authorization: `Bearer ${localStorage.getItem('token')}`
}))

function getCoverUrl(coverPath: string): string {
  // If it's already a full URL, return it
  if (coverPath.startsWith('http')) return coverPath
  // Otherwise, construct presigned URL request (simplified - adjust based on your API)
  return `${baseUrl.value}/api/tracks/cover/${encodeURIComponent(coverPath)}`
}

function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60)
  const secs = seconds % 60
  return `${mins}:${secs.toString().padStart(2, '0')}`
}

async function loadTracks() {
  loading.value = true
  try {
    const response = await api.get('/api/tracks', {
      params: { page: pagination.page, pageSize: pagination.pageSize }
    })
    tracks.value = response.data.tracks
    pagination.total = response.data.totalCount
  } catch (error) {
    ElMessage.error('加载曲目失败')
  } finally {
    loading.value = false
  }
}

function handleUploadSuccess() {
  ElMessage.success('上传成功')
  loadTracks()
}

function handleUploadError() {
  ElMessage.error('上传失败')
}

async function playTrack(track: any) {
  // Cleanup previous blob URL
  if (audioBlobUrl.value) {
    URL.revokeObjectURL(audioBlobUrl.value)
    audioBlobUrl.value = ''
  }
  
  currentTrack.value = track
  
  try {
    // Fetch audio with auth header and create blob URL
    const response = await api.get(`/api/tracks/${track.id}/stream`, {
      responseType: 'blob'
    })
    audioBlobUrl.value = URL.createObjectURL(response.data)
    
    // Wait for DOM update before playing
    setTimeout(() => {
      audioRef.value?.play()
    }, 100)
  } catch (error) {
    ElMessage.error('加载音频失败')
    currentTrack.value = null
  }
}

function stopPlayback() {
  audioRef.value?.pause()
  if (audioBlobUrl.value) {
    URL.revokeObjectURL(audioBlobUrl.value)
    audioBlobUrl.value = ''
  }
  currentTrack.value = null
}

function onAudioEnded() {
  // Optionally play next track or just stop
}

function editTrack(track: any) {
  editForm.id = track.id
  editForm.title = track.title
  editForm.coverUrl = track.coverUrl || ''
  editForm.lyricsUrl = track.lyricsUrl || ''
  editDialogVisible.value = true
}

function handleCoverUpload(response: any) {
  if (response.coverUrl) {
    editForm.coverUrl = response.coverUrl
    ElMessage.success('封面上传成功')
  }
}

function handleLyricsUpload(response: any) {
  if (response.lyricsUrl) {
    editForm.lyricsUrl = response.lyricsUrl
    ElMessage.success('歌词上传成功')
  }
}

async function saveTrack() {
  try {
    await api.put(`/api/tracks/${editForm.id}`, {
      title: editForm.title,
      coverUrl: editForm.coverUrl || null,
      lyricsUrl: editForm.lyricsUrl || null
    })
    ElMessage.success('保存成功')
    editDialogVisible.value = false
    loadTracks()
  } catch (error) {
    ElMessage.error('保存失败')
  }
}

async function deleteTrack(id: string) {
  try {
    await ElMessageBox.confirm('确定删除此曲目？', '确认')
    await api.delete(`/api/tracks/${id}`)
    ElMessage.success('删除成功')
    loadTracks()
  } catch (error: any) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

onMounted(loadTracks)
</script>

<style scoped>
.tracks-view {
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

.upload-btn {
  padding: 12px 24px;
  font-weight: 600;
}

/* Content Card */
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

/* Table Styles */
.custom-table {
  border-radius: var(--radius-md);
}

.track-cover {
  width: 50px;
  height: 50px;
  border-radius: 8px;
  object-fit: cover;
}

.cover-placeholder {
  width: 50px;
  height: 50px;
  border-radius: 8px;
  background: linear-gradient(135deg, #f0f0f0 0%, #e0e0e0 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #bbb;
  font-size: 20px;
}

.track-title {
  font-weight: 600;
  color: #ffffff;
}

.artist-name {
  color: rgba(255, 255, 255, 0.65);
}

.duration {
  font-family: 'SF Mono', monospace;
  color: rgba(255, 255, 255, 0.6);
  font-size: 13px;
}

.format-tag {
  text-transform: uppercase;
  font-size: 11px;
}

.action-buttons {
  display: flex;
  align-items: center;
  gap: 8px;
}

.action-btn.play {
  font-size: 18px;
}

/* Pagination */
.pagination {
  padding: 16px 20px;
  justify-content: flex-end;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
}

/* Audio Player */
.audio-player {
  position: fixed;
  bottom: 0;
  left: 240px;
  right: 0;
  height: 80px;
  background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
  display: flex;
  align-items: center;
  padding: 0 24px;
  gap: 16px;
  box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.3);
  z-index: 1000;
}

.slide-up-enter-active,
.slide-up-leave-active {
  transition: all 0.3s ease;
}

.slide-up-enter-from,
.slide-up-leave-to {
  transform: translateY(100%);
  opacity: 0;
}

.player-info {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 200px;
}

.player-cover {
  width: 56px;
  height: 56px;
  border-radius: 8px;
}

.player-cover-placeholder {
  width: 56px;
  height: 56px;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.1);
  display: flex;
  align-items: center;
  justify-content: center;
  color: rgba(255, 255, 255, 0.5);
  font-size: 24px;
}

.player-text {
  color: #fff;
}

.player-title {
  font-weight: 600;
  font-size: 14px;
}

.player-artist {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.6);
}

.player-audio {
  flex: 1;
  height: 40px;
}

.player-close {
  color: rgba(255, 255, 255, 0.8);
  background: rgba(255, 255, 255, 0.1);
  border: none;
}

.player-close:hover {
  background: rgba(255, 255, 255, 0.2);
}

/* Edit Dialog */
.cover-upload-area {
  display: flex;
  align-items: center;
  gap: 16px;
}

.edit-cover-preview {
  width: 100px;
  height: 100px;
  border-radius: 8px;
}

.lyrics-upload-area {
  display: flex;
  align-items: center;
}
</style>
