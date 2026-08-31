export type MusicImportBatchStatus =
  | 'pending'
  | 'scanning'
  | 'ready'
  | 'analyzing'
  | 'grouping'
  | 'awaitingReview'
  | 'readyToApply'
  | 'applying'
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
  | 'sourceValidation'
  | 'hashing'
  | 'metadata'
  | 'fingerprinting'
  | 'analyzed'
  | 'grouped'
  | 'awaitingReview'
  | 'applying'
  | 'verified'
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
  canIngest: boolean
  sourceAvailable: boolean
  sourceAlias: string
  processingConcurrency: number
  fingerprintAvailable: boolean
  fingerprintVersion: string | null
  fingerprintAlgorithm: number
  fingerprintErrorCode: string | null
  fingerprintErrorMessage: string | null
}

export interface MusicImportPhaseProgress {
  sourceValidation: number
  hashing: number
  metadata: number
  fingerprinting: number
  analyzed: number
  grouped: number
  awaitingReview: number
  applying: number
  verified: number
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
  phases: MusicImportPhaseProgress
}

export type MusicImportReviewStatus =
  | 'open'
  | 'confirmed'
  | 'locked'
  | 'applied'
  | 'deferred'
  | 'conflict'
  | 'failed'

export type MusicImportDecisionKind =
  | 'createTrack'
  | 'replaceExistingTrack'
  | 'keepExistingTrack'
  | 'treatAsSeparateRecording'
  | 'rejectDuplicate'
  | 'defer'

export type MusicImportMatchKind =
  | 'none'
  | 'exactSha256'
  | 'acousticFingerprint'
  | 'userSeparated'

export type MusicImportSourceKind = 'mountedDirectory' | 'browserStaging'

export interface MusicImportReviewSummary {
  open: number
  confirmed: number
  locked: number
  applied: number
  deferred: number
  conflict: number
  failed: number
}

export interface MusicImportExistingTrack {
  id: string
  title: string
  originalFileName: string | null
  codec: string | null
  container: string | null
  isLossless: boolean | null
  sampleRateHz: number | null
  bitDepth: number | null
  channels: number | null
  bitRateKbps: number | null
  fileSizeBytes: number | null
  exactDurationMilliseconds: number | null
}

export interface MusicImportReviewCandidate {
  id: string
  version: number
  relativePath: string
  sourceLabel: string
  originalFileName: string
  sourceKind: MusicImportSourceKind
  extractedTitle: string | null
  extractedArtist: string | null
  extractedAlbum: string | null
  codec: string | null
  container: string | null
  isLossless: boolean | null
  sampleRateHz: number | null
  bitDepth: number | null
  channels: number | null
  bitRateKbps: number | null
  sizeBytes: number
  exactDurationMilliseconds: number | null
  decision: MusicImportDecisionKind | null
  decisionTrackId: string | null
  previewAvailable: boolean
  previewUrl: string | null
}

export interface MusicImportReviewGroup {
  id: string
  batchId: string
  status: MusicImportReviewStatus
  matchKind: MusicImportMatchKind
  matchExplanation: string
  version: number
  existingTrackId: string | null
  existingTrack: MusicImportExistingTrack | null
  recommendedItemId: string | null
  recommendationExplanation: string | null
  fingerprintVersion: string | null
  fingerprintAlgorithm: number | null
  overallSimilarity: number | null
  minimumSegmentSimilarity: number | null
  coverageFraction: number | null
  alignmentOffsetFrames: number | null
  confirmedByUserId: string | null
  confirmedAt: string | null
  decisionKind: MusicImportDecisionKind | null
  selectedItemIds: string[]
  applyErrorCode: string | null
  applyErrorMessage: string | null
  cleanupStatus: string | null
  cleanupErrorCode: string | null
  cleanupErrorMessage: string | null
  candidates: MusicImportReviewCandidate[]
}

export interface MusicImportReviewPage {
  batchId: string
  status: MusicImportBatchStatus
  version: number
  summary: MusicImportReviewSummary
  groups: MusicImportReviewGroup[]
  totalCount: number
  page: number
  pageSize: number
  totalPages: number
}

export interface MusicImportReviewPageParams {
  page: number
  pageSize: number
}

export interface MusicImportReviewDecisionRequest {
  expectedVersion: number
  decisionKind: MusicImportDecisionKind
  selectedItemIds: string[]
}

export interface MusicImportReviewVersionRequest {
  groupId: string
  expectedVersion: number
}

export interface MusicImportLockRequest {
  groups: MusicImportReviewVersionRequest[]
}

export interface MusicImportReviewBatchState {
  id: string
  status: MusicImportBatchStatus
  version: number
}

export interface MusicImportBatchSummary {
  id: string
  requestedByUserId: string
  clientRequestId: string
  relativeDirectory: string
  sourceKind: MusicImportSourceKind
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

export interface MusicImportUploadAccepted {
  batchId: string
  itemId: string
  status: MusicImportBatchStatus
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
  analyzing: '正在分析',
  grouping: '正在分组',
  awaitingReview: '等待人工复核',
  readyToApply: '等待应用决定',
  applying: '正在应用决定',
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
  analyzing: 'primary',
  grouping: 'primary',
  awaitingReview: 'warning',
  readyToApply: 'warning',
  applying: 'primary',
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
