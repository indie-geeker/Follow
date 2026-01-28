<template>
  <div class="tags-view">
    <div class="page-header">
      <div class="header-left">
        <p class="page-subtitle">管理音乐标签分类</p>
      </div>
      <el-button type="primary" :icon="Plus" @click="showCreateDialog" class="create-btn">
        新建标签
      </el-button>
    </div>

    <el-card class="content-card">
      <el-table :data="tags" v-loading="loading" style="width: 100%" class="custom-table">
        <el-table-column label="封面" width="80">
          <template #default="{ row }">
            <el-image
              v-if="row.coverUrl"
              :src="getCoverUrl(row.coverUrl)"
              fit="cover"
              class="tag-cover"
            />
            <div v-else class="cover-placeholder">
              <el-icon><PriceTag /></el-icon>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="name" label="标签名称" min-width="150">
          <template #default="{ row }">
            <span class="tag-name">{{ row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="category" label="分类" width="120">
          <template #default="{ row }">
            <el-tag v-if="row.category" size="small" class="category-tag">{{ row.category }}</el-tag>
            <span v-else class="no-category">-</span>
          </template>
        </el-table-column>
        <el-table-column prop="trackCount" label="曲目数" width="100">
          <template #default="{ row }">
            <span class="track-count">{{ row.trackCount }}</span>
          </template>
        </el-table-column>
        <el-table-column label="创建时间" width="180">
          <template #default="{ row }">
            <span class="date">{{ formatDate(row.createdAt) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <div class="action-buttons">
              <el-button link type="primary" @click="editTag(row)">
                编辑
              </el-button>
              <el-button link type="danger" @click="deleteTag(row.id)">
                删除
              </el-button>
            </div>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- Create/Edit Dialog -->
    <el-dialog 
      v-model="dialogVisible" 
      :title="isEditing ? '编辑标签' : '新建标签'" 
      width="450px" 
      class="custom-dialog"
    >
      <el-form :model="tagForm" label-width="80px">
        <el-form-item label="标签名称" required>
          <el-input v-model="tagForm.name" placeholder="输入标签名称" />
        </el-form-item>
        <el-form-item label="分类">
          <el-select v-model="tagForm.category" placeholder="选择分类" clearable style="width: 100%">
            <el-option label="风格" value="风格" />
            <el-option label="榜单" value="榜单" />
            <el-option label="场景" value="场景" />
            <el-option label="心情" value="心情" />
            <el-option label="年代" value="年代" />
          </el-select>
        </el-form-item>
        <el-form-item label="封面URL">
          <el-input v-model="tagForm.coverUrl" placeholder="可选，输入封面图片URL" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveTag" :loading="saving">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, PriceTag } from '@element-plus/icons-vue'
import api from '@/api'

interface Tag {
  id: string
  name: string
  category: string | null
  coverUrl: string | null
  trackCount: number
  createdAt: string
}

const loading = ref(false)
const saving = ref(false)
const tags = ref<Tag[]>([])
const dialogVisible = ref(false)
const isEditing = ref(false)
const editingId = ref<string | null>(null)

const tagForm = reactive({
  name: '',
  category: '',
  coverUrl: ''
})

const baseUrl = computed(() => import.meta.env.VITE_API_URL || 'http://localhost:5000')

function getCoverUrl(coverPath: string): string {
  if (coverPath.startsWith('http')) return coverPath
  return `${baseUrl.value}/api/tracks/cover/${encodeURIComponent(coverPath)}`
}

function formatDate(dateStr: string): string {
  return new Date(dateStr).toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  })
}

async function loadTags() {
  loading.value = true
  try {
    const response = await api.get('/api/tags')
    tags.value = response.data
  } catch (error) {
    ElMessage.error('加载标签失败')
  } finally {
    loading.value = false
  }
}

function showCreateDialog() {
  isEditing.value = false
  editingId.value = null
  tagForm.name = ''
  tagForm.category = ''
  tagForm.coverUrl = ''
  dialogVisible.value = true
}

function editTag(tag: Tag) {
  isEditing.value = true
  editingId.value = tag.id
  tagForm.name = tag.name
  tagForm.category = tag.category || ''
  tagForm.coverUrl = tag.coverUrl || ''
  dialogVisible.value = true
}

async function saveTag() {
  if (!tagForm.name.trim()) {
    ElMessage.warning('请输入标签名称')
    return
  }

  saving.value = true
  try {
    const payload = {
      name: tagForm.name.trim(),
      category: tagForm.category || null,
      coverUrl: tagForm.coverUrl || null
    }

    if (isEditing.value && editingId.value) {
      await api.put(`/api/tags/${editingId.value}`, payload)
      ElMessage.success('标签更新成功')
    } else {
      await api.post('/api/tags', payload)
      ElMessage.success('标签创建成功')
    }

    dialogVisible.value = false
    loadTags()
  } catch (error: any) {
    const msg = error.response?.data?.message || (isEditing.value ? '更新失败' : '创建失败')
    ElMessage.error(msg)
  } finally {
    saving.value = false
  }
}

async function deleteTag(id: string) {
  try {
    await ElMessageBox.confirm('确定删除此标签？删除后不可恢复。', '确认删除', {
      type: 'warning'
    })
    await api.delete(`/api/tags/${id}`)
    ElMessage.success('删除成功')
    loadTags()
  } catch (error: any) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

onMounted(loadTags)
</script>

<style scoped>
.tags-view {
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

.create-btn {
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

.tag-cover {
  width: 50px;
  height: 50px;
  border-radius: 8px;
  object-fit: cover;
}

.cover-placeholder {
  width: 50px;
  height: 50px;
  border-radius: 8px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 20px;
}

.tag-name {
  font-weight: 600;
  color: #ffffff;
}

.category-tag {
  text-transform: capitalize;
}

.no-category {
  color: rgba(255, 255, 255, 0.4);
}

.track-count {
  font-family: 'SF Mono', monospace;
  color: rgba(255, 255, 255, 0.8);
}

.date {
  color: rgba(255, 255, 255, 0.6);
  font-size: 13px;
}

.action-buttons {
  display: flex;
  gap: 8px;
}
</style>
