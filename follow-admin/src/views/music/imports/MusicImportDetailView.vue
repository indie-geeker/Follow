<template>
  <div class="detail-page">
    <div class="detail-nav">
      <button type="button" class="back-link" @click="router.push({ name: 'MusicImports' })">
        <el-icon><ArrowLeft /></el-icon>
        返回任务列表
      </button>
      <span class="poll-state" :class="{ 'poll-state--active': pollingActive }">
        <span aria-hidden="true"></span>
        {{ pollingStatusText }}
      </span>
    </div>

    <div v-if="pageError" class="inline-notice" role="alert">
      <span>{{ pageError }}</span>
      <el-button link type="danger" @click="loadAll">重试</el-button>
    </div>

    <template v-if="batch">
      <section class="batch-hero">
        <div class="batch-hero__main">
          <span class="eyebrow">IMPORT JOB {{ shortId(batch.id) }}</span>
          <div class="title-line">
            <h2>{{ displayBatchSource(batch) }}</h2>
            <el-tag :type="musicImportBatchStatusTones[batch.status]" effect="dark">
              {{ musicImportBatchStatusLabels[batch.status] }}
            </el-tag>
          </div>
          <p>{{ batchSourceDescription }}</p>
        </div>
        <div class="batch-actions">
          <el-button
            v-if="batch.status === 'awaitingReview'"
            type="primary"
            @click="router.push({ name: 'MusicImportReview', params: { jobId: batch.id } })"
          >
            进入人工复核
          </el-button>
          <el-button
            v-for="action in availableActions"
            :key="action"
            :type="action === 'cancel' ? 'danger' : 'primary'"
            :plain="action === 'cancel'"
            :loading="activeAction === action"
            :disabled="Boolean(activeAction)"
            @click="runAction(action)"
          >
            {{ actionLabels[action] }}
          </el-button>
        </div>

        <div class="hero-progress">
          <div class="hero-progress__meta">
            <span>{{ completedItems }} / {{ batch.discoveredFileCount }} 个文件已处理</span>
            <strong>{{ progress }}%</strong>
          </div>
          <progress :value="progress" max="100" aria-label="导入任务完成进度"></progress>
          <div class="hero-progress__bytes">
            {{ formatMusicImportBytes(batch.progress.processedBytes) }} / {{ formatMusicImportBytes(batch.totalBytes) }}
          </div>
        </div>
      </section>

      <section class="metric-strip" aria-label="导入结果摘要">
        <div class="metric metric--success">
          <span>IMPORTED</span>
          <strong>{{ batch.progress.imported }}</strong>
          <small>成功导入</small>
        </div>
        <div class="metric metric--duplicate">
          <span>DEDUPED</span>
          <strong>{{ batch.progress.duplicate }}</strong>
          <small>重复跳过</small>
        </div>
        <div class="metric">
          <span>SKIPPED</span>
          <strong>{{ batch.progress.skipped }}</strong>
          <small>策略跳过</small>
        </div>
        <div class="metric metric--danger">
          <span>FAILED</span>
          <strong>{{ batch.progress.failed }}</strong>
          <small>处理失败</small>
        </div>
      </section>

      <div v-if="batch.lastError" class="batch-error" role="alert">
        <strong>{{ batch.lastErrorCode || 'IMPORT_ERROR' }}</strong>
        <span>{{ batch.lastError }}</span>
      </div>

      <el-card class="items-panel">
        <div class="panel-toolbar">
          <div>
            <span class="eyebrow">FILE LEDGER</span>
            <h3>文件处理明细</h3>
          </div>
          <div class="toolbar-actions">
            <el-select
              v-model="itemStatusFilter"
              clearable
              placeholder="全部文件状态"
              aria-label="按文件状态筛选"
              @change="handleItemFilterChange"
            >
              <el-option
                v-for="option in itemStatusOptions"
                :key="option.value"
                :label="option.label"
                :value="option.value"
              />
            </el-select>
            <el-button :loading="itemsLoading" @click="loadItems">刷新明细</el-button>
          </div>
        </div>

        <el-table
          v-loading="itemsLoading"
          :data="items"
          empty-text="扫描后将在此显示文件"
          class="items-table"
        >
          <el-table-column label="相对路径" min-width="300">
            <template #default="{ row }">
              <div class="path-cell">
                <strong>{{ row.originalFileName }}</strong>
                <span :title="row.relativePath">{{ row.relativePath }}</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="状态" width="130">
            <template #default="{ row }">
              <el-tag :type="itemStatusTone(row.status)" size="small">
                {{ itemStatusLabel(row.status) }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column label="大小" width="110">
            <template #default="{ row }">
              <span class="mono-value">{{ formatMusicImportBytes(row.sizeBytes) }}</span>
            </template>
          </el-table-column>
          <el-table-column label="尝试" width="80">
            <template #default="{ row }">
              <span class="mono-value">{{ row.attemptCount }}</span>
            </template>
          </el-table-column>
          <el-table-column label="结果 / 错误" min-width="240">
            <template #default="{ row }">
              <div v-if="row.errorMessage" class="item-error">
                <strong>{{ row.errorCode || 'FILE_ERROR' }}</strong>
                <span>{{ row.errorMessage }}</span>
              </div>
              <span v-else-if="row.trackId" class="track-result">曲目 {{ shortId(row.trackId) }}</span>
              <span v-else class="muted-value">—</span>
            </template>
          </el-table-column>
          <el-table-column label="更新时间" width="150">
            <template #default="{ row }">
              <span class="muted-value">{{ formatDate(row.updatedAt) }}</span>
            </template>
          </el-table-column>
        </el-table>

        <AdminPagination
          v-model:current-page="pagination.page"
          :page-size="pagination.pageSize"
          :total="pagination.total"
          @current-change="loadItems"
        />
      </el-card>
    </template>

    <div v-else-if="loadingBatch" class="loading-shell" aria-live="polite">
      正在读取导入任务…
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { ArrowLeft } from '@element-plus/icons-vue'
import musicImports, { getAvailableMusicImportActions } from '@/api/musicImports'
import AdminPagination from '@/components/AdminPagination.vue'
import type {
  MusicImportAction,
  MusicImportBatchDetail,
  MusicImportItem,
  MusicImportItemStatus
} from '@/types/musicImport'
import {
  calculateMusicImportProgress,
  completedMusicImportItems,
  formatMusicImportBytes,
  musicImportBatchStatusLabels,
  musicImportBatchStatusTones,
  musicImportItemStatusLabels,
  musicImportItemStatusTones
} from '@/types/musicImport'
import { getApiErrorMessage } from '@/utils/apiError'
import { createLatestRequestGate } from '@/utils/latestRequest'

const route = useRoute()
const router = useRouter()
const batchId = String(route.params.jobId)
const batch = ref<MusicImportBatchDetail | null>(null)
const items = ref<MusicImportItem[]>([])
const loadingBatch = ref(false)
const itemsLoading = ref(false)
const pageError = ref('')
const activeAction = ref<MusicImportAction | null>(null)
const itemStatusFilter = ref<MusicImportItemStatus | ''>('')
const pagination = reactive({ page: 1, pageSize: 20, total: 0 })
const pollTimer = ref<ReturnType<typeof setTimeout> | null>(null)
const pollingActive = ref(false)
const batchRequestGate = createLatestRequestGate()
const itemRequestGate = createLatestRequestGate()

const actionLabels: Record<MusicImportAction, string> = {
  start: '开始相似分析',
  pause: '暂停分析',
  resume: '继续分析',
  cancel: '取消任务',
  retryFailures: '重试失败项'
}

const itemStatusOptions = (Object.entries(musicImportItemStatusLabels) as [MusicImportItemStatus, string][])
  .map(([value, label]) => ({ value, label }))

const progress = computed(() => batch.value
  ? calculateMusicImportProgress(batch.value)
  : 0)

const completedItems = computed(() => batch.value
  ? completedMusicImportItems(batch.value.progress)
  : 0)

const availableActions = computed(() => batch.value
  ? getAvailableMusicImportActions(batch.value.status, batch.value.progress.retryableFailed)
  : [])

const batchSourceDescription = computed(() => batch.value?.sourceKind === 'browserStaging'
  ? '源文件来自浏览器上传暂存。应用决定前不会写入曲目库；取消任务会清理暂存文件。'
  : '源文件来自服务器只读挂载。取消任务只停止后续处理，已导入曲目会被保留。')

const pollingStatusText = computed(() => {
  if (pollingActive.value) return '每 3 秒同步服务器状态'
  if (batch.value && isTerminalStatus(batch.value.status)) return '任务已结束，自动同步已停止'
  return '自动同步已暂停'
})

async function loadBatch(showLoading = false) {
  const requestToken = batchRequestGate.begin()
  if (showLoading) loadingBatch.value = true
  try {
    const response = await musicImports.getBatch(batchId)
    if (!batchRequestGate.isLatest(requestToken)) return

    batch.value = response
    pageError.value = ''
    if (isTerminalStatus(batch.value.status)) stopPolling()
  } catch (error) {
    if (!batchRequestGate.isLatest(requestToken)) return
    pageError.value = getApiErrorMessage(error, '导入任务状态加载失败')
  } finally {
    if (batchRequestGate.isLatest(requestToken)) loadingBatch.value = false
  }
}

async function loadItems() {
  const requestToken = itemRequestGate.begin()
  itemsLoading.value = true
  try {
    const response = await musicImports.listItems(batchId, {
      page: pagination.page,
      pageSize: pagination.pageSize,
      status: itemStatusFilter.value || undefined
    })
    if (!itemRequestGate.isLatest(requestToken)) return

    items.value = response.items
    pagination.total = response.totalCount
  } catch (error) {
    if (!itemRequestGate.isLatest(requestToken)) return
    ElMessage.error(getApiErrorMessage(error, '文件明细加载失败'))
  } finally {
    if (itemRequestGate.isLatest(requestToken)) itemsLoading.value = false
  }
}

async function loadAll() {
  await Promise.all([loadBatch(true), loadItems()])
}

function handleItemFilterChange() {
  pagination.page = 1
  void loadItems()
}

async function runAction(action: MusicImportAction) {
  if (activeAction.value) return

  if (action === 'cancel') {
    try {
      await ElMessageBox.confirm(
        '取消后将停止扫描和后续文件处理；已经成功导入的曲目会保留。是否继续？',
        '取消导入任务',
        { confirmButtonText: '确认取消', cancelButtonText: '返回', type: 'warning' }
      )
    } catch {
      return
    }
  }

  stopPolling()
  invalidatePendingReads()
  activeAction.value = action
  try {
    if (action === 'start') await musicImports.start(batchId)
    if (action === 'pause') await musicImports.pause(batchId)
    if (action === 'resume') await musicImports.resume(batchId)
    if (action === 'cancel') await musicImports.cancel(batchId)
    if (action === 'retryFailures') await musicImports.retryFailures(batchId)

    invalidatePendingReads()
    ElMessage.success(`${actionLabels[action]}请求已提交`)
    await Promise.all([loadBatch(), loadItems()])
  } catch (error) {
    ElMessage.error(getApiErrorMessage(error, `${actionLabels[action]}失败`))
  } finally {
    activeAction.value = null
    if (batch.value && !isTerminalStatus(batch.value.status)) schedulePoll()
  }
}

function schedulePoll() {
  if (pollingActive.value || (batch.value && isTerminalStatus(batch.value.status))) return
  pollingActive.value = true
  scheduleNextPoll()
}

function scheduleNextPoll() {
  if (!pollingActive.value) return

  pollTimer.value = setTimeout(async () => {
    pollTimer.value = null
    await pollServerState()
    if (pollingActive.value) scheduleNextPoll()
  }, 3000)
}

async function pollServerState() {
  await Promise.all([loadBatch(), loadItems()])
}

function stopPolling() {
  pollingActive.value = false
  if (pollTimer.value) {
    clearTimeout(pollTimer.value)
    pollTimer.value = null
  }
}

function invalidatePendingReads() {
  batchRequestGate.invalidate()
  itemRequestGate.invalidate()
  loadingBatch.value = false
  itemsLoading.value = false
}

function isTerminalStatus(status: MusicImportBatchDetail['status']): boolean {
  return ['cancelled', 'completed', 'completedWithErrors', 'failed'].includes(status)
}

function shortId(value: string): string {
  return value.slice(0, 8).toUpperCase()
}

function displayDirectory(relativeDirectory: string): string {
  return relativeDirectory || '挂载根目录'
}

function displayBatchSource(value: MusicImportBatchDetail): string {
  return value.sourceKind === 'browserStaging'
    ? '浏览器上传暂存'
    : displayDirectory(value.relativeDirectory)
}

function itemStatusLabel(status: MusicImportItemStatus): string {
  return musicImportItemStatusLabels[status]
}

function itemStatusTone(status: MusicImportItemStatus) {
  return musicImportItemStatusTones[status]
}

function formatDate(value: string): string {
  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  }).format(new Date(value))
}

onMounted(async () => {
  await loadAll()
  schedulePoll()
})

onBeforeUnmount(() => {
  stopPolling()
  invalidatePendingReads()
})
</script>

<style scoped>
.detail-page {
  display: grid;
  gap: 18px;
}

.detail-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.back-link {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  min-height: 40px;
  padding: 0;
  color: rgba(255, 255, 255, 0.72);
  background: none;
  border: 0;
  cursor: pointer;
}

.back-link:hover {
  color: #fff;
}

.poll-state {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  color: rgba(255, 255, 255, 0.48);
  font: 11px/1.2 'SF Mono', ui-monospace, monospace;
}

.poll-state span {
  width: 7px;
  height: 7px;
  background: rgba(255, 255, 255, 0.32);
  border-radius: 50%;
}

.poll-state--active span {
  background: #34d399;
  box-shadow: 0 0 0 4px rgba(52, 211, 153, 0.1);
}

.inline-notice,
.batch-error {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 12px 16px;
  color: #fecaca;
  background: rgba(127, 29, 29, 0.36);
  border: 1px solid rgba(248, 113, 113, 0.34);
  border-radius: var(--radius-md);
}

.batch-hero {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 20px 28px;
  padding: 26px;
  color: #fff;
  background:
    radial-gradient(circle at 95% 0%, rgba(34, 211, 238, 0.13), transparent 32%),
    linear-gradient(150deg, rgba(79, 70, 229, 0.2), transparent 52%),
    rgba(15, 23, 42, 0.58);
  border: 1px solid rgba(129, 140, 248, 0.25);
  border-radius: var(--radius-lg);
  box-shadow: 0 18px 48px rgba(3, 7, 18, 0.3);
  backdrop-filter: blur(20px);
}

.eyebrow {
  color: #9ca3ff;
  font: 700 11px/1.2 'SF Mono', ui-monospace, monospace;
  letter-spacing: 0.12em;
}

.title-line {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
  margin: 6px 0 8px;
}

.title-line h2 {
  margin: 0;
  font-size: clamp(22px, 3vw, 30px);
  overflow-wrap: anywhere;
}

.batch-hero__main p {
  max-width: 720px;
  margin: 0;
  color: rgba(255, 255, 255, 0.58);
  font-size: 13px;
  line-height: 1.6;
}

.batch-actions {
  display: flex;
  align-items: flex-start;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 8px;
}

.batch-actions .el-button {
  margin: 0;
}

.hero-progress {
  display: grid;
  grid-column: 1 / -1;
  gap: 8px;
}

.hero-progress__meta {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  color: rgba(255, 255, 255, 0.65);
  font-size: 13px;
}

.hero-progress__meta strong {
  color: #fff;
  font: 700 14px/1 'SF Mono', ui-monospace, monospace;
}

.hero-progress__bytes {
  color: rgba(255, 255, 255, 0.42);
  font: 11px/1.2 'SF Mono', ui-monospace, monospace;
  text-align: right;
}

progress {
  width: 100%;
  height: 9px;
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

.metric-strip {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  overflow: hidden;
  background: rgba(15, 23, 42, 0.52);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: var(--radius-lg);
  backdrop-filter: blur(16px);
}

.metric {
  display: grid;
  gap: 4px;
  min-width: 0;
  padding: 18px 20px;
  border-right: 1px solid rgba(255, 255, 255, 0.08);
}

.metric:last-child {
  border-right: 0;
}

.metric > span {
  color: rgba(255, 255, 255, 0.42);
  font: 700 10px/1 'SF Mono', ui-monospace, monospace;
  letter-spacing: 0.12em;
}

.metric strong {
  color: #fff;
  font: 700 26px/1.2 'SF Mono', ui-monospace, monospace;
}

.metric small {
  color: rgba(255, 255, 255, 0.56);
}

.metric--success strong {
  color: #6ee7b7;
}

.metric--duplicate strong {
  color: #67e8f9;
}

.metric--danger strong {
  color: #fca5a5;
}

.batch-error {
  justify-content: flex-start;
  align-items: baseline;
}

.batch-error strong {
  flex: 0 0 auto;
  font: 700 11px/1.2 'SF Mono', ui-monospace, monospace;
}

.items-panel {
  overflow: hidden;
  background: rgba(15, 23, 42, 0.52);
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: var(--radius-lg);
  box-shadow: 0 16px 44px rgba(3, 7, 18, 0.24);
  backdrop-filter: blur(20px);
}

.items-panel :deep(.el-card__body) {
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

.panel-toolbar h3 {
  margin: 5px 0 0;
  color: #fff;
  font-size: 18px;
}

.toolbar-actions {
  display: flex;
  gap: 10px;
}

.toolbar-actions :deep(.el-select) {
  width: 180px;
}

.items-table {
  --el-table-bg-color: transparent;
  --el-table-tr-bg-color: transparent;
  --el-table-header-bg-color: rgba(255, 255, 255, 0.055);
  --el-table-row-hover-bg-color: rgba(255, 255, 255, 0.065);
  --el-table-border-color: rgba(255, 255, 255, 0.08);
  --el-table-text-color: rgba(255, 255, 255, 0.82);
  --el-table-header-text-color: rgba(255, 255, 255, 0.62);
}

.path-cell,
.item-error {
  display: grid;
  gap: 4px;
}

.path-cell strong {
  color: rgba(255, 255, 255, 0.9);
}

.path-cell span {
  max-width: 460px;
  overflow: hidden;
  color: rgba(255, 255, 255, 0.42);
  font: 11px/1.4 'SF Mono', ui-monospace, monospace;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.mono-value,
.muted-value {
  color: rgba(255, 255, 255, 0.5);
  font: 12px/1.4 'SF Mono', ui-monospace, monospace;
}

.track-result {
  color: #6ee7b7;
  font: 12px/1.4 'SF Mono', ui-monospace, monospace;
}

.item-error strong {
  color: #fca5a5;
  font: 700 10px/1.2 'SF Mono', ui-monospace, monospace;
}

.item-error span {
  color: rgba(254, 202, 202, 0.76);
  font-size: 12px;
}

.loading-shell {
  display: grid;
  place-items: center;
  min-height: 260px;
  color: rgba(255, 255, 255, 0.62);
  background: rgba(15, 23, 42, 0.42);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: var(--radius-lg);
}

@media (max-width: 900px) {
  .batch-hero {
    grid-template-columns: 1fr;
  }

  .batch-actions {
    justify-content: flex-start;
  }

  .metric-strip {
    grid-template-columns: repeat(2, 1fr);
  }

  .metric:nth-child(2) {
    border-right: 0;
  }

  .metric:nth-child(-n + 2) {
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  }
}

@media (max-width: 767px) {
  .detail-nav,
  .panel-toolbar {
    align-items: stretch;
    flex-direction: column;
  }

  .poll-state {
    align-self: flex-start;
  }

  .toolbar-actions,
  .toolbar-actions :deep(.el-select) {
    width: 100%;
  }

  .batch-hero {
    padding: 20px;
  }

  .batch-actions .el-button {
    flex: 1 1 auto;
  }
}
</style>
