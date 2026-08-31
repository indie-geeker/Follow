<template>
  <div class="music-import-page">
    <section class="source-status" :class="{ 'source-status--ready': sourceReady }">
      <div class="source-status__signal" aria-hidden="true"></div>
      <div class="source-status__copy">
        <span class="eyebrow">SERVER SOURCE</span>
        <strong>{{ sourceStatusTitle }}</strong>
        <p>{{ sourceStatusDescription }}</p>
      </div>
      <el-button
        type="primary"
        :disabled="!sourceReady"
        @click="router.push({ name: 'MusicImportCreate' })"
      >
        创建导入任务
      </el-button>
    </section>

    <div v-if="errorMessage" class="inline-notice inline-notice--danger" role="alert">
      <span>{{ errorMessage }}</span>
      <el-button link type="danger" @click="loadBatches">重试</el-button>
    </div>

    <el-card class="operations-panel">
      <div class="panel-toolbar">
        <div>
          <span class="eyebrow">IMPORT OPERATIONS</span>
          <h2>任务队列</h2>
        </div>
        <div class="toolbar-actions">
          <el-select
            v-model="statusFilter"
            clearable
            placeholder="全部状态"
            aria-label="按任务状态筛选"
            @change="handleFilterChange"
          >
            <el-option
              v-for="option in statusOptions"
              :key="option.value"
              :label="option.label"
              :value="option.value"
            />
          </el-select>
          <el-button :loading="loading" @click="loadBatches">刷新</el-button>
        </div>
      </div>

      <el-table
        v-loading="loading"
        :data="batches"
        empty-text="暂无音乐导入任务"
        class="operations-table"
      >
        <el-table-column label="目录 / 任务" min-width="230">
          <template #default="{ row }">
            <button class="batch-link" type="button" @click="openDetail(row.id)">
              <strong>{{ displayBatchSource(row) }}</strong>
              <span>{{ shortId(row.id) }} · {{ formatDate(row.createdAt) }}</span>
            </button>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="150">
          <template #default="{ row }">
            <el-tag :type="batchStatusTone(row.status)" effect="dark">
              {{ batchStatusLabel(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="进度" min-width="210">
          <template #default="{ row }">
            <div class="progress-cell">
              <div class="progress-cell__meta">
                <span>{{ completedMusicImportItems(row.progress) }} / {{ row.discoveredFileCount }} 个文件</span>
                <strong>{{ calculateMusicImportProgress(row) }}%</strong>
              </div>
              <progress
                :value="calculateMusicImportProgress(row)"
                max="100"
                :aria-label="`${displayBatchSource(row)} 导入进度`"
              ></progress>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="结果" min-width="210">
          <template #default="{ row }">
            <div class="result-counts">
              <span class="result-counts__success">导入 {{ row.progress.imported }}</span>
              <span>去重 {{ row.progress.duplicate }}</span>
              <span :class="{ 'result-counts__danger': row.progress.failed > 0 }">
                失败 {{ row.progress.failed }}
              </span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="数据量" width="120">
          <template #default="{ row }">
            <span class="mono-value">{{ formatMusicImportBytes(row.totalBytes) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openDetail(row.id)">查看</el-button>
            <el-button
              v-if="row.status === 'awaitingReview'"
              link
              type="warning"
              @click="openReview(row.id)"
            >人工复核</el-button>
          </template>
        </el-table-column>
      </el-table>

      <AdminPagination
        v-model:current-page="pagination.page"
        :page-size="pagination.pageSize"
        :total="pagination.total"
        @current-change="loadBatches"
      />
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import musicImports from '@/api/musicImports'
import AdminPagination from '@/components/AdminPagination.vue'
import type {
  MusicImportBatchStatus,
  MusicImportBatchSummary,
  MusicImportCapabilities
} from '@/types/musicImport'
import {
  calculateMusicImportProgress,
  completedMusicImportItems,
  formatMusicImportBytes,
  musicImportBatchStatusLabels,
  musicImportBatchStatusTones
} from '@/types/musicImport'
import { getApiErrorMessage } from '@/utils/apiError'

const router = useRouter()
const loading = ref(false)
const batches = ref<MusicImportBatchSummary[]>([])
const capabilities = ref<MusicImportCapabilities | null>(null)
const errorMessage = ref('')
const statusFilter = ref<MusicImportBatchStatus | ''>('')
const pagination = reactive({ page: 1, pageSize: 20, total: 0 })

const statusOptions = (Object.entries(musicImportBatchStatusLabels) as [MusicImportBatchStatus, string][])
  .map(([value, label]) => ({ value, label }))

const sourceReady = computed(() => Boolean(
  capabilities.value?.enabled &&
  capabilities.value?.canIngest &&
  capabilities.value.sourceAvailable
))

const sourceStatusTitle = computed(() => {
  if (!capabilities.value) return '正在检查导入能力'
  if (!capabilities.value.enabled) return '音乐库初始化功能未启用'
  if (!capabilities.value.fingerprintAvailable) return '声学指纹服务未就绪'
  if (!capabilities.value.sourceAvailable) return '服务器尚未配置音乐目录'
  return capabilities.value.sourceAlias
    ? `已连接：${capabilities.value.sourceAlias}`
    : '服务器音乐目录已就绪'
})

const sourceStatusDescription = computed(() => {
  if (capabilities.value && !capabilities.value.fingerprintAvailable) {
    return `声学指纹不可用时禁止新建导入任务：${capabilities.value.fingerprintErrorCode || 'FINGERPRINT_UNAVAILABLE'}。`
  }
  if (!sourceReady.value) {
    return '需要运维人员启用功能，并以只读方式挂载服务器目录后才能创建任务。'
  }
  return `源目录按服务器只读挂载契约提供；当前处理并发数为 ${capabilities.value?.processingConcurrency ?? 1}。`
})

async function loadCapabilities() {
  try {
    capabilities.value = await musicImports.getCapabilities()
  } catch (error) {
    ElMessage.error(getApiErrorMessage(error, '无法读取音乐导入能力'))
  }
}

async function loadBatches() {
  loading.value = true
  errorMessage.value = ''
  try {
    const response = await musicImports.listBatches({
      page: pagination.page,
      pageSize: pagination.pageSize,
      status: statusFilter.value || undefined
    })
    batches.value = response.batches
    pagination.total = response.totalCount
  } catch (error) {
    errorMessage.value = getApiErrorMessage(error, '导入任务加载失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

function handleFilterChange() {
  pagination.page = 1
  void loadBatches()
}

function openDetail(batchId: string) {
  void router.push({ name: 'MusicImportDetail', params: { jobId: batchId } })
}

function openReview(batchId: string) {
  void router.push({ name: 'MusicImportReview', params: { jobId: batchId } })
}

function shortId(batchId: string): string {
  return batchId.slice(0, 8).toUpperCase()
}

function displayDirectory(relativeDirectory: string): string {
  return relativeDirectory || '挂载根目录'
}

function displayBatchSource(value: MusicImportBatchSummary): string {
  return value.sourceKind === 'browserStaging'
    ? '浏览器上传暂存'
    : displayDirectory(value.relativeDirectory)
}

function batchStatusLabel(status: MusicImportBatchStatus): string {
  return musicImportBatchStatusLabels[status]
}

function batchStatusTone(status: MusicImportBatchStatus) {
  return musicImportBatchStatusTones[status]
}

function formatDate(value: string): string {
  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  }).format(new Date(value))
}

onMounted(() => {
  void Promise.all([loadCapabilities(), loadBatches()])
})
</script>

<style scoped>
.music-import-page {
  display: grid;
  gap: 20px;
  animation: importPageIn 0.35s ease-out;
}

@keyframes importPageIn {
  from { opacity: 0; transform: translateY(6px); }
  to { opacity: 1; transform: translateY(0); }
}

.source-status {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: center;
  gap: 16px;
  padding: 18px 20px;
  color: #fff;
  background: rgba(15, 23, 42, 0.58);
  border: 1px solid rgba(251, 191, 36, 0.38);
  border-radius: var(--radius-lg);
  box-shadow: 0 12px 36px rgba(3, 7, 18, 0.22);
  backdrop-filter: blur(18px);
}

.source-status--ready {
  border-color: rgba(52, 211, 153, 0.4);
}

.source-status__signal {
  width: 12px;
  height: 12px;
  background: #fbbf24;
  border: 3px solid rgba(251, 191, 36, 0.2);
  border-radius: 50%;
  box-shadow: 0 0 0 6px rgba(251, 191, 36, 0.08);
}

.source-status--ready .source-status__signal {
  background: #34d399;
  border-color: rgba(52, 211, 153, 0.2);
  box-shadow: 0 0 0 6px rgba(52, 211, 153, 0.08);
}

.source-status__copy {
  display: grid;
  gap: 4px;
}

.source-status__copy strong {
  font-size: 16px;
}

.source-status__copy p {
  margin: 0;
  color: rgba(255, 255, 255, 0.68);
  font-size: 13px;
}

.eyebrow {
  color: #9ca3ff;
  font: 700 11px/1.2 'SF Mono', ui-monospace, monospace;
  letter-spacing: 0.12em;
}

.inline-notice {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 12px 16px;
  color: #fee2e2;
  background: rgba(127, 29, 29, 0.42);
  border: 1px solid rgba(248, 113, 113, 0.38);
  border-radius: var(--radius-md);
}

.operations-panel {
  overflow: hidden;
  background: rgba(15, 23, 42, 0.52);
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: var(--radius-lg);
  box-shadow: 0 16px 44px rgba(3, 7, 18, 0.28);
  backdrop-filter: blur(20px);
}

.operations-panel :deep(.el-card__body) {
  padding: 0;
}

.panel-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
  padding: 20px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.panel-toolbar h2 {
  margin: 4px 0 0;
  color: #fff;
  font-size: 20px;
}

.toolbar-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}

.toolbar-actions :deep(.el-select) {
  width: 170px;
}

.operations-table {
  --el-table-bg-color: transparent;
  --el-table-tr-bg-color: transparent;
  --el-table-header-bg-color: rgba(255, 255, 255, 0.055);
  --el-table-row-hover-bg-color: rgba(255, 255, 255, 0.065);
  --el-table-border-color: rgba(255, 255, 255, 0.08);
  --el-table-text-color: rgba(255, 255, 255, 0.82);
  --el-table-header-text-color: rgba(255, 255, 255, 0.62);
}

.batch-link {
  display: grid;
  gap: 5px;
  padding: 4px 0;
  color: #fff;
  text-align: left;
  background: none;
  border: 0;
  cursor: pointer;
}

.batch-link:hover strong {
  color: #a5b4fc;
}

.batch-link span,
.mono-value {
  color: rgba(255, 255, 255, 0.52);
  font: 12px/1.4 'SF Mono', ui-monospace, monospace;
}

.progress-cell {
  display: grid;
  gap: 7px;
}

.progress-cell__meta {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  color: rgba(255, 255, 255, 0.62);
  font-size: 12px;
}

.progress-cell__meta strong {
  color: #fff;
  font-variant-numeric: tabular-nums;
}

progress {
  width: 100%;
  height: 7px;
  overflow: hidden;
  appearance: none;
  background: rgba(255, 255, 255, 0.1);
  border: 0;
  border-radius: 999px;
}

progress::-webkit-progress-bar {
  background: rgba(255, 255, 255, 0.1);
}

progress::-webkit-progress-value {
  background: linear-gradient(90deg, #818cf8, #22d3ee);
  border-radius: 999px;
}

progress::-moz-progress-bar {
  background: linear-gradient(90deg, #818cf8, #22d3ee);
  border-radius: 999px;
}

.result-counts {
  display: flex;
  flex-wrap: wrap;
  gap: 4px 12px;
  color: rgba(255, 255, 255, 0.58);
  font-size: 12px;
}

.result-counts__success {
  color: #6ee7b7;
}

.result-counts__danger {
  color: #fca5a5;
}

@media (max-width: 767px) {
  .source-status {
    grid-template-columns: auto minmax(0, 1fr);
  }

  .source-status .el-button {
    grid-column: 1 / -1;
    width: 100%;
  }

  .panel-toolbar {
    align-items: stretch;
    flex-direction: column;
  }

  .toolbar-actions,
  .toolbar-actions :deep(.el-select) {
    width: 100%;
  }

  .toolbar-actions .el-button {
    flex: 0 0 auto;
  }
}
</style>
