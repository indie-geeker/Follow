<template>
  <div class="tracks-view">
    <div class="page-header">
      <div class="header-left">
        <p class="page-subtitle">管理和上传您的音乐曲目</p>
      </div>
      <div class="upload-actions">
        <el-button
          :icon="FolderOpened"
          @click="router.push({ name: 'MusicImportCreate' })"
        >
          初始化音乐库
        </el-button>
        <el-upload
          :http-request="uploadTrack"
          :on-success="handleUploadSuccess"
          :on-error="handleUploadError"
          :show-file-list="false"
          accept=".mp3,.flac,.wav,.m4a,.aac,.ogg"
        >
          <el-button type="primary" :icon="Upload" class="upload-btn">上传音乐</el-button>
        </el-upload>
      </div>
    </div>

    <el-card class="content-card">
      <el-table
        :data="tracks"
        v-loading="loading"
        empty-text="暂无曲目"
        style="width: 100%"
        class="custom-table"
      >
        <el-table-column label="封面" width="80">
          <template #default="{ row }">
            <el-image
              v-if="toCoverProxyUrl(row.coverUrl)"
              :src="toCoverProxyUrl(row.coverUrl)"
              :preview-src-list="[toCoverProxyUrl(row.coverUrl)]"
              :preview-teleported="true"
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
        <el-table-column label="歌词" width="100">
          <template #default="{ row }">
            <div class="lyrics-cell">
              <el-tag v-if="row.lyricsUrl" type="success" size="small">有</el-tag>
              <el-tag v-else type="info" size="small">无</el-tag>
              <el-button 
                v-if="row.lyricsUrl" 
                link 
                type="primary" 
                size="small" 
                @click="viewLyrics(row)"
              >
                查看
              </el-button>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <div class="action-buttons">
              <el-button
                link
                type="primary"
                class="action-btn play"
                :aria-label="`播放：${row.title}`"
                :title="`播放：${row.title}`"
                @click="playTrack(row)"
              >
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

      <AdminPagination
        v-model:current-page="pagination.page"
        :page-size="pagination.pageSize"
        :total="pagination.total"
        @current-change="loadTracks"
      />
    </el-card>

    <!-- Audio Player -->
    <Transition name="slide-up">
      <div v-if="currentTrack" class="audio-player">
        <div class="player-info">
          <el-image
            v-if="toCoverProxyUrl(currentTrack.coverUrl)"
            :src="toCoverProxyUrl(currentTrack.coverUrl)"
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
          @error="handlePlaybackError"
          class="player-audio"
        />
        <el-button
          :icon="Close"
          circle
          size="small"
          aria-label="关闭播放器"
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
              v-if="toCoverProxyUrl(editForm.coverUrl)"
              :src="toCoverProxyUrl(editForm.coverUrl)"
              fit="cover"
              class="edit-cover-preview"
            />
            <el-upload
              :http-request="uploadTrackCover"
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
              :http-request="uploadTrackLyrics"
              :show-file-list="false"
              :on-success="handleLyricsUpload"
              accept=".lrc,.txt"
              style="margin-left: 10px;"
            >
              <el-button size="small" type="primary">{{ editForm.lyricsUrl ? '更换歌词' : '上传歌词' }}</el-button>
            </el-upload>
          </div>
        </el-form-item>
        <el-form-item label="标签">
          <el-select
            v-model="editForm.tagIds"
            multiple
            placeholder="选择标签"
            style="width: 100%"
            :loading="loadingTags"
          >
            <el-option
              v-for="tag in allTags"
              :key="tag.id"
              :label="tag.name"
              :value="tag.id"
            >
              <span>{{ tag.name }}</span>
              <span v-if="tag.category" style="margin-left: 8px; color: #999; font-size: 12px;">{{ tag.category }}</span>
            </el-option>
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveTrack">保存</el-button>
      </template>
    </el-dialog>

    <!-- Lyrics View Dialog -->
    <el-dialog v-model="lyricsDialogVisible" title="查看歌词" width="600px" class="custom-dialog">
      <div v-loading="lyricsLoading" class="lyrics-content">
        <div v-if="currentLyrics" class="lyrics-text">
          <pre>{{ currentLyrics }}</pre>
        </div>
        <div v-else-if="!lyricsLoading" class="no-lyrics">
          暂无歌词内容
        </div>
      </div>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onBeforeUnmount, onMounted, computed, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Upload, VideoPlay, Close, Picture, Headset, FolderOpened } from '@element-plus/icons-vue'
import api, { refreshSession } from '@/api'
import { createApiUpload } from '@/api/upload'
import AdminPagination from '@/components/AdminPagination.vue'
import { normalizeCoverObjectKey, toCoverProxyUrl } from '@/utils/coverUrl'

const router = useRouter()
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
const streamUrl = ref('')
const playbackRefreshAttempted = ref(false)

const editDialogVisible = ref(false)
const editForm = reactive({
  id: '',
  title: '',
  coverUrl: '',
  lyricsUrl: '',
  tagIds: [] as string[]
})

// Lyrics view state
const lyricsDialogVisible = ref(false)
const currentLyrics = ref('')
const lyricsLoading = ref(false)

// Tags state
const allTags = ref<any[]>([])
const loadingTags = ref(false)

const uploadUrl = computed(() => '/api/tracks/upload')

const coverUploadUrl = computed(() => `/api/tracks/${editForm.id}/cover`)

const lyricsUploadUrl = computed(() => `/api/tracks/${editForm.id}/lyrics`)

const uploadTrack = createApiUpload(() => uploadUrl.value)
const uploadTrackCover = createApiUpload(() => coverUploadUrl.value)
const uploadTrackLyrics = createApiUpload(() => lyricsUploadUrl.value)

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
  stopPlayback()
  currentTrack.value = track
  playbackRefreshAttempted.value = false
  streamUrl.value = `/api/tracks/${track.id}/stream`

  await nextTick()
  try {
    await audioRef.value?.play()
  } catch {
    // Browser autoplay policy may require the native play control.
  }
}

function stopPlayback() {
  const audio = audioRef.value
  audio?.pause()
  audio?.removeAttribute('src')
  audio?.load()
  streamUrl.value = ''
  playbackRefreshAttempted.value = false
  currentTrack.value = null
}

async function handlePlaybackError() {
  if (!streamUrl.value) return

  if (!playbackRefreshAttempted.value) {
    playbackRefreshAttempted.value = true
    const failedUrl = streamUrl.value
    try {
      await refreshSession()
      if (streamUrl.value !== failedUrl) return

      streamUrl.value = ''
      await nextTick()
      streamUrl.value = failedUrl
      await nextTick()
      audioRef.value?.load()
      try {
        await audioRef.value?.play()
      } catch {
        // The refreshed stream remains available through the native play control.
      }
      return
    } catch {
      // The shared refresh handler redirects when the cookie session is no longer valid.
    }
  }

  ElMessage.error('加载音频失败')
  stopPlayback()
}

function onAudioEnded() {
  // Optionally play next track or just stop
}

async function editTrack(track: any) {
  editForm.id = track.id
  editForm.title = track.title
  editForm.coverUrl = normalizeCoverObjectKey(track.coverUrl) ?? ''
  editForm.lyricsUrl = track.lyricsUrl || ''
  editForm.tagIds = []
  editDialogVisible.value = true

  // Load all tags if not already loaded
  if (allTags.value.length === 0) {
    loadingTags.value = true
    try {
      const response = await api.get('/api/tags')
      allTags.value = response.data
    } catch (error) {
      console.error('Failed to load tags')
    } finally {
      loadingTags.value = false
    }
  }

  // Load track's current tags
  try {
    const response = await api.get(`/api/tracks/${track.id}/tags`)
    editForm.tagIds = response.data.map((t: any) => t.id)
  } catch (error) {
    console.error('Failed to load track tags')
  }
}

function handleCoverUpload(response: any) {
  const coverObjectKey = normalizeCoverObjectKey(response.coverUrl)
  if (coverObjectKey) {
    editForm.coverUrl = coverObjectKey
    ElMessage.success('封面上传成功')
  }
}

function handleLyricsUpload(response: any) {
  if (response.lyricsUrl) {
    editForm.lyricsUrl = response.lyricsUrl
    ElMessage.success('歌词上传成功')
  }
}

async function viewLyrics(track: any) {
  lyricsDialogVisible.value = true
  lyricsLoading.value = true
  currentLyrics.value = ''
  
  try {
    const response = await api.get(`/api/tracks/${track.id}/lyrics`, {
      responseType: 'text'
    })
    currentLyrics.value = response.data
  } catch (error) {
    ElMessage.error('获取歌词失败')
    currentLyrics.value = '获取歌词失败'
  } finally {
    lyricsLoading.value = false
  }
}

async function saveTrack() {
  try {
    await api.put(`/api/tracks/${editForm.id}`, {
      title: editForm.title,
      lyricsUrl: editForm.lyricsUrl || null
    })
    
    // Save tags
    await api.put(`/api/tracks/${editForm.id}/tags`, {
      tagIds: editForm.tagIds
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
onBeforeUnmount(stopPlayback)
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

.upload-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}

.upload-actions .el-button {
  min-height: 40px;
  margin: 0;
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

.lyrics-cell {
  display: flex;
  align-items: center;
  gap: 8px;
}

/* Lyrics View */
.lyrics-content {
  max-height: 70vh;
  overflow-y: auto;
  padding: 16px;
  background: #1a1a1a; /* Dark background */
  border-radius: 8px;
}

.lyrics-text pre {
  white-space: pre-wrap;
  font-family: inherit;
  margin: 0;
  line-height: 1.6;
  color: #e0e0e0; /* Light text */
}

.no-lyrics {
  text-align: center;
  color: #909399;
  padding: 20px;
}

@media (max-width: 640px) {
  .page-header {
    align-items: stretch;
    flex-direction: column;
    gap: 14px;
  }

  .upload-actions {
    width: 100%;
  }

  .upload-actions > .el-button,
  .upload-actions :deep(.el-upload),
  .upload-actions :deep(.el-upload .el-button) {
    flex: 1;
    width: 100%;
  }
}
</style>
