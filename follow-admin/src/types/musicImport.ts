export type MusicImportBatchStatus =
  | 'pending'
  | 'scanning'
  | 'ready'
  | 'running'
  | 'pauseRequested'
  | 'paused'
  | 'cancelRequested'
  | 'cancelled'
  | 'verifying'
  | 'completed'
  | 'completedWithErrors'
  | 'failed'

export type MusicImportItemStatus =
  | 'pending'
  | 'processing'
  | 'imported'
  | 'duplicate'
  | 'skipped'
  | 'failed'
  | 'cancelled'

export type MusicImportItemStage =
  | 'none'
  | 'hashing'
  | 'parsing'
  | 'uploading'
  | 'persisting'

export type MusicImportAction =
  | 'start'
  | 'pause'
  | 'resume'
  | 'cancel'
  | 'retryFailures'

export interface MusicImportCapabilities {
  enabled: boolean
  sourceAvailable: boolean
  sourceAlias: string
  processingConcurrency: number
}

export interface MusicImportProgress {
  pending: number
  processing: number
  imported: number
  duplicate: number
  skipped: number
  failed: number
  retryableFailed: number
  cancelled: number
  processedBytes: number
}

export interface MusicImportBatchSummary {
  id: string
  requestedByUserId: string
  clientRequestId: string
  relativeDirectory: string
  autoStart: boolean
  status: MusicImportBatchStatus
  discoveredFileCount: number
  ignoredFileCount: number
  totalBytes: number
  progress: MusicImportProgress
  lastErrorCode: string | null
  lastError: string | null
  createdAt: string
  updatedAt: string
  scanStartedAt: string | null
  scanCompletedAt: string | null
  startedAt: string | null
  completedAt: string | null
}

export type MusicImportBatchDetail = MusicImportBatchSummary

export interface MusicImportItem {
  id: string
  relativePath: string
  originalFileName: string
  sizeBytes: number
  sourceModifiedAt: string
  status: MusicImportItemStatus
  stage: MusicImportItemStage
  attemptCount: number
  retryable: boolean
  trackId: string | null
  errorCode: string | null
  errorMessage: string | null
  createdAt: string
  updatedAt: string
  startedAt: string | null
  completedAt: string | null
}

export interface MusicImportBatchListResponse {
  batches: MusicImportBatchSummary[]
  totalCount: number
  page: number
  pageSize: number
  totalPages: number
}

export interface MusicImportItemListResponse {
  items: MusicImportItem[]
  totalCount: number
  page: number
  pageSize: number
  totalPages: number
}

export interface CreateMusicImportRequest {
  clientRequestId: string
  relativeDirectory: string
  autoStart?: boolean
}

export interface MusicImportBatchListParams {
  page: number
  pageSize: number
  status?: MusicImportBatchStatus
}

export interface MusicImportItemListParams {
  page: number
  pageSize: number
  status?: MusicImportItemStatus
}

export const musicImportBatchStatusLabels: Record<MusicImportBatchStatus, string> = {
  pending: '等待扫描',
  scanning: '正在扫描',
  ready: '等待开始',
  running: '正在导入',
  pauseRequested: '正在暂停',
  paused: '已暂停',
  cancelRequested: '正在取消',
  cancelled: '已取消',
  verifying: '正在核验',
  completed: '已完成',
  completedWithErrors: '完成但有错误',
  failed: '任务失败'
}

export const musicImportItemStatusLabels: Record<MusicImportItemStatus, string> = {
  pending: '等待处理',
  processing: '正在处理',
  imported: '已导入',
  duplicate: '已去重',
  skipped: '已跳过',
  failed: '失败',
  cancelled: '已取消'
}

export const musicImportBatchStatusTones: Record<
  MusicImportBatchStatus,
  'success' | 'warning' | 'danger' | 'info' | 'primary'
> = {
  pending: 'info',
  scanning: 'primary',
  ready: 'warning',
  running: 'primary',
  pauseRequested: 'warning',
  paused: 'warning',
  cancelRequested: 'warning',
  cancelled: 'info',
  verifying: 'primary',
  completed: 'success',
  completedWithErrors: 'warning',
  failed: 'danger'
}

export const musicImportItemStatusTones: Record<
  MusicImportItemStatus,
  'success' | 'warning' | 'danger' | 'info' | 'primary'
> = {
  pending: 'info',
  processing: 'primary',
  imported: 'success',
  duplicate: 'success',
  skipped: 'info',
  failed: 'danger',
  cancelled: 'info'
}

export function musicImportBatchStatusLabel(status: MusicImportBatchStatus): string {
  return musicImportBatchStatusLabels[status]
}

export function formatMusicImportBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return '0 B'

  const units = ['B', 'KB', 'MB', 'GB', 'TB'] as const
  const unitIndex = Math.min(
    Math.floor(Math.log(bytes) / Math.log(1024)),
    units.length - 1
  )
  const value = bytes / (1024 ** unitIndex)
  const precision = unitIndex === 0 || value >= 10 ? 0 : 1
  return `${Number(value.toFixed(precision))} ${units[unitIndex]}`
}

export function calculateMusicImportProgress(summary: {
  discoveredFileCount: number
  progress: Pick<
    MusicImportProgress,
    'imported' | 'duplicate' | 'skipped' | 'failed' | 'cancelled'
  >
}): number {
  if (summary.discoveredFileCount <= 0) return 0
  const completedItems = completedMusicImportItems(summary.progress)
  return Math.min(100, Math.max(0, Math.round(
    (completedItems / summary.discoveredFileCount) * 100
  )))
}

export function completedMusicImportItems(progress: Pick<
  MusicImportProgress,
  'imported' | 'duplicate' | 'skipped' | 'failed' | 'cancelled'
>): number {
  return progress.imported +
    progress.duplicate +
    progress.skipped +
    progress.failed +
    progress.cancelled
}
