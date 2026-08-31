import type {
  MusicImportDecisionKind,
  MusicImportLockRequest,
  MusicImportMatchKind,
  MusicImportReviewCandidate,
  MusicImportReviewDecisionRequest,
  MusicImportReviewGroup,
  MusicImportReviewSummary
} from '@/types/musicImport'

export interface MusicImportReviewDecisionDraft {
  decisionKind: MusicImportDecisionKind | null
  candidateId: string | null
}

export function createReviewDecisionDraft(
  _group: MusicImportReviewGroup
): MusicImportReviewDecisionDraft {
  return {
    decisionKind: null,
    candidateId: null
  }
}

export function formatCandidateQuality(candidate: MusicImportReviewCandidate): string {
  const facts: string[] = []
  const format = candidate.container ?? candidate.codec
  if (format) facts.push(format.toUpperCase())
  facts.push(candidate.isLossless === true
    ? '无损'
    : candidate.isLossless === false
      ? '有损'
      : '压缩类型未知')
  if (candidate.sampleRateHz !== null) {
    facts.push(`${formatDecimal(candidate.sampleRateHz / 1000)} kHz`)
  }
  if (candidate.bitDepth !== null) facts.push(`${candidate.bitDepth}-bit`)
  if (candidate.channels !== null) {
    facts.push(candidate.channels === 1
      ? '单声道'
      : candidate.channels === 2
        ? '双声道'
        : `${candidate.channels} 声道`)
  }
  if (candidate.bitRateKbps !== null) facts.push(`${candidate.bitRateKbps} kbps`)
  facts.push(formatBytes(candidate.sizeBytes))
  if (candidate.exactDurationMilliseconds !== null) {
    facts.push(formatDuration(candidate.exactDurationMilliseconds))
  }
  return facts.join(' · ')
}

export function recommendationDisplay(group: MusicImportReviewGroup): string {
  const candidate = group.candidates.find(item => item.id === group.recommendedItemId)
  if (!candidate) return '系统未给出候选建议'
  const explanation = group.recommendationExplanation?.trim()
  return explanation
    ? `系统建议：${candidate.originalFileName}（${explanation}）`
    : `系统建议：${candidate.originalFileName}`
}

export function buildDecisionRequest(
  group: MusicImportReviewGroup,
  draft: MusicImportReviewDecisionDraft
): MusicImportReviewDecisionRequest {
  const decisionKind = draft.decisionKind
  if (decisionKind === null) throw new Error('请选择审核决定。')
  const requiresExisting = decisionKind === 'replaceExistingTrack' ||
    decisionKind === 'keepExistingTrack' ||
    decisionKind === 'rejectDuplicate'
  if (requiresExisting && group.existingTrackId === null) {
    throw new Error('该决定需要已匹配的现有曲目。')
  }

  const selectsOne = decisionKind === 'createTrack' || decisionKind === 'replaceExistingTrack'
  let selectedItemIds: string[]
  if (selectsOne) {
    if (draft.candidateId === null) throw new Error('请选择一个候选文件。')
    if (!group.candidates.some(candidate => candidate.id === draft.candidateId)) {
      throw new Error('所选候选文件不属于当前审核组。')
    }
    selectedItemIds = [draft.candidateId]
  } else {
    selectedItemIds = group.candidates.map(candidate => candidate.id)
    if (selectedItemIds.length === 0) throw new Error('当前审核组没有候选文件。')
  }

  return {
    expectedVersion: group.version,
    decisionKind,
    selectedItemIds
  }
}

export function buildApplyRequest(
  groups: MusicImportReviewGroup[],
  expectedTotalCount: number
): MusicImportLockRequest {
  if (groups.length !== expectedTotalCount || new Set(groups.map(group => group.id)).size !== groups.length) {
    throw new Error('应用决定前必须加载并包含全部审核组。')
  }
  if (groups.some(group => group.status !== 'confirmed' && group.status !== 'applied')) {
    throw new Error('仍有审核组尚未确认。')
  }
  if (!groups.some(group => group.status === 'confirmed')) {
    throw new Error('没有待应用的已确认审核组。')
  }
  return {
    groups: groups.map(group => ({
      groupId: group.id,
      expectedVersion: group.version
    }))
  }
}

export function canApplyReviewSummary(
  summary: MusicImportReviewSummary,
  totalCount: number
): boolean {
  if (totalCount <= 0 || summary.confirmed <= 0) return false
  return summary.open === 0 &&
    summary.locked === 0 &&
    summary.deferred === 0 &&
    summary.conflict === 0 &&
    summary.failed === 0 &&
    summary.confirmed + summary.applied === totalCount
}

export function normalizeReviewConflict(error: unknown): MusicImportReviewGroup | null {
  if (typeof error !== 'object' || error === null) return null
  const response = (error as { response?: unknown }).response
  if (typeof response !== 'object' || response === null) return null
  const typed = response as { status?: unknown; data?: unknown }
  if (typed.status !== 409 || typeof typed.data !== 'object' || typed.data === null) return null
  return typed.data as MusicImportReviewGroup
}

export function isFileSelectionDecision(
  decisionKind: MusicImportDecisionKind | null
): boolean {
  return decisionKind === 'createTrack' ||
    decisionKind === 'replaceExistingTrack' ||
    decisionKind === 'treatAsSeparateRecording'
}

export function canTreatAsSeparateRecording(matchKind: MusicImportMatchKind): boolean {
  return matchKind !== 'exactSha256'
}

function formatDecimal(value: number): string {
  return Number.isInteger(value) ? String(value) : String(Number(value.toFixed(1)))
}

function formatBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB', 'TB'] as const
  const index = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1)
  const value = bytes / (1024 ** index)
  return `${Number(value.toFixed(index === 0 || value >= 10 ? 0 : 1))} ${units[index]}`
}

function formatDuration(milliseconds: number): string {
  const seconds = Math.max(0, Math.round(milliseconds / 1000))
  const minutes = Math.floor(seconds / 60)
  return `${minutes}:${String(seconds % 60).padStart(2, '0')}`
}
