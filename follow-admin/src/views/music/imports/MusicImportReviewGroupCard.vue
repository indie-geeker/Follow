<template>
  <article class="review-card" :aria-labelledby="`review-title-${group.id}`">
    <header class="review-card__header">
      <div>
        <span class="review-card__index">REVIEW {{ sequence }}</span>
        <h2 :id="`review-title-${group.id}`">{{ primaryTitle }}</h2>
        <p>{{ group.matchExplanation }}</p>
      </div>
      <div class="review-card__status">
        <el-tag :type="statusTone" effect="dark">{{ statusLabel }}</el-tag>
        <span v-if="group.overallSimilarity !== null">
          匹配度 {{ formatPercent(group.overallSimilarity) }}
        </span>
      </div>
    </header>

    <section v-if="group.existingTrack" class="existing-track" aria-label="匹配到的现有曲目">
      <span>现有曲目</span>
      <strong>{{ group.existingTrack.title }}</strong>
      <small>
        {{ group.existingTrack.container || '格式未知' }} ·
        {{ group.existingTrack.codec || '编码未知' }} ·
        {{ group.existingTrack.sampleRateHz ? `${group.existingTrack.sampleRateHz / 1000} kHz` : '采样率未知' }}
      </small>
    </section>

    <div class="match-facts" aria-label="重复匹配依据">
      <span>类型 {{ matchKindLabel }}</span>
      <span v-if="group.minimumSegmentSimilarity !== null">
        最低片段 {{ formatPercent(group.minimumSegmentSimilarity) }}
      </span>
      <span v-if="group.coverageFraction !== null">
        覆盖 {{ formatPercent(group.coverageFraction) }}
      </span>
      <span v-if="group.alignmentOffsetFrames !== null">
        偏移 {{ group.alignmentOffsetFrames }} 帧
      </span>
    </div>

    <div class="candidate-grid" role="list" aria-label="候选音频文件">
      <section
        v-for="candidate in group.candidates"
        :key="candidate.id"
        class="candidate"
        :class="{
          'candidate--recommended': candidate.id === group.recommendedItemId,
          'candidate--selected': isAdministratorSelected(candidate.id)
        }"
        role="listitem"
      >
        <div class="candidate__headline">
          <div class="candidate__name">
            <strong :title="candidate.originalFileName">{{ candidate.originalFileName }}</strong>
            <span :title="candidate.sourceLabel">{{ candidate.sourceLabel }}</span>
          </div>
          <div class="candidate__badges">
            <span
              v-if="candidate.id === group.recommendedItemId"
              class="recommendation-badge"
            >系统建议</span>
            <span
              v-if="isAdministratorSelected(candidate.id)"
              class="selection-badge"
            >管理员已选择</span>
          </div>
        </div>

        <dl class="quality-facts">
          <div><dt>格式</dt><dd>{{ candidate.container || '未知' }}</dd></div>
          <div><dt>编码</dt><dd>{{ candidate.codec || '未知' }}</dd></div>
          <div><dt>压缩</dt><dd>{{ losslessLabel(candidate.isLossless) }}</dd></div>
          <div><dt>采样率</dt><dd>{{ sampleRateLabel(candidate.sampleRateHz) }}</dd></div>
          <div><dt>位深</dt><dd>{{ candidate.bitDepth ? `${candidate.bitDepth}-bit` : '未知' }}</dd></div>
          <div><dt>声道</dt><dd>{{ channelsLabel(candidate.channels) }}</dd></div>
          <div><dt>码率</dt><dd>{{ candidate.bitRateKbps ? `${candidate.bitRateKbps} kbps` : '未知' }}</dd></div>
          <div><dt>大小</dt><dd>{{ formatMusicImportBytes(candidate.sizeBytes) }}</dd></div>
          <div><dt>时长</dt><dd>{{ durationLabel(candidate.exactDurationMilliseconds) }}</dd></div>
        </dl>

        <p
          v-if="candidate.id === group.recommendedItemId && group.recommendationExplanation"
          class="recommendation-copy"
        >
          {{ group.recommendationExplanation }}。这只是质量建议，不代表已选中。
        </p>

        <div class="candidate__controls">
          <el-radio
            v-if="requiresCandidate"
            :model-value="draft.candidateId"
            :value="candidate.id"
            :aria-label="`选择候选文件：${candidate.originalFileName}`"
            @change="emit('candidate-change', candidate.id)"
          >
            选择此文件
          </el-radio>
          <el-button
            v-if="candidate.previewAvailable && candidate.previewUrl"
            link
            type="primary"
            :aria-label="`试听：${candidate.originalFileName}`"
            @click="togglePreview(candidate.id)"
          >
            {{ previewItemId === candidate.id ? '收起试听' : '试听' }}
          </el-button>
        </div>
        <audio
          v-if="previewItemId === candidate.id && candidate.previewAvailable && candidate.previewUrl"
          :src="candidate.previewUrl"
          controls
          preload="none"
          class="candidate__audio"
          :aria-label="`试听文件：${candidate.originalFileName}`"
        />
      </section>
    </div>

    <section class="decision-panel" aria-label="管理员审核决定">
      <div class="decision-panel__heading">
        <div>
          <strong>管理员决定</strong>
          <span>系统不会代替你勾选候选项</span>
        </div>
        <span v-if="group.decisionKind" class="saved-decision" role="status">
          已保存：{{ decisionLabel(group.decisionKind) }}
        </span>
      </div>
      <el-radio-group
        :model-value="draft.decisionKind"
        class="decision-options"
        aria-label="选择审核决定"
        @change="emit('decision-change', $event as MusicImportDecisionKind)"
      >
        <el-radio value="createTrack">新建曲目</el-radio>
        <el-radio value="replaceExistingTrack" :disabled="!group.existingTrackId">替换现有音频</el-radio>
        <el-radio value="keepExistingTrack" :disabled="!group.existingTrackId">保留现有曲目</el-radio>
        <el-radio
          v-if="canTreatAsSeparateRecording(group.matchKind)"
          value="treatAsSeparateRecording"
        >作为不同录音</el-radio>
        <el-radio value="rejectDuplicate" :disabled="!group.existingTrackId">拒绝重复文件</el-radio>
        <el-radio value="defer">暂缓决定</el-radio>
      </el-radio-group>
      <div class="decision-panel__footer">
        <span>版本 {{ group.version }} · 保存时会校验并发修改</span>
        <el-button type="primary" :loading="busy" @click="emit('save')">保存本组决定</el-button>
      </div>
    </section>

    <div v-if="group.applyErrorMessage" class="review-error" role="alert">
      <strong>{{ group.applyErrorCode || 'APPLY_ERROR' }}</strong>
      <span>{{ group.applyErrorMessage }}</span>
    </div>
    <div v-if="group.cleanupErrorMessage" class="review-error" role="alert">
      <strong>{{ group.cleanupErrorCode || 'CLEANUP_ERROR' }}</strong>
      <span>{{ group.cleanupErrorMessage }}</span>
    </div>
  </article>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import type {
  MusicImportDecisionKind,
  MusicImportReviewGroup
} from '@/types/musicImport'
import { formatMusicImportBytes } from '@/types/musicImport'
import {
  canTreatAsSeparateRecording,
  isFileSelectionDecision,
  type MusicImportReviewDecisionDraft
} from '@/utils/musicImportReview'

const props = defineProps<{
  group: MusicImportReviewGroup
  draft: MusicImportReviewDecisionDraft
  sequence: number
  busy: boolean
}>()

const emit = defineEmits<{
  'decision-change': [value: MusicImportDecisionKind]
  'candidate-change': [value: string]
  save: []
}>()

const previewItemId = ref<string | null>(null)
const requiresCandidate = computed(() =>
  props.draft.decisionKind === 'createTrack' ||
  props.draft.decisionKind === 'replaceExistingTrack')
const primaryTitle = computed(() => props.group.candidates[0]?.extractedTitle ||
  props.group.candidates[0]?.originalFileName || '未命名候选组')
const statusLabel = computed(() => ({
  open: '待决定',
  confirmed: '已确认',
  locked: '已锁定',
  applied: '已应用',
  deferred: '已暂缓',
  conflict: '版本冲突',
  failed: '应用失败'
}[props.group.status]))
const statusTone = computed(() => ({
  open: 'warning',
  confirmed: 'success',
  locked: 'primary',
  applied: 'success',
  deferred: 'info',
  conflict: 'danger',
  failed: 'danger'
}[props.group.status] as 'warning' | 'success' | 'primary' | 'info' | 'danger'))
const matchKindLabel = computed(() => ({
  none: '无确定匹配',
  exactSha256: '内容哈希一致',
  acousticFingerprint: '声学指纹相似',
  userSeparated: '人工区分录音'
}[props.group.matchKind]))

function togglePreview(candidateId: string) {
  previewItemId.value = previewItemId.value === candidateId ? null : candidateId
}

function isAdministratorSelected(candidateId: string): boolean {
  const effectiveDecision = props.draft.decisionKind ?? props.group.decisionKind
  if (!isFileSelectionDecision(effectiveDecision)) return false
  if (props.draft.decisionKind === 'treatAsSeparateRecording') return true
  if (props.draft.decisionKind !== null) return props.draft.candidateId === candidateId
  return props.group.selectedItemIds.includes(candidateId)
}

function losslessLabel(value: boolean | null): string {
  return value === true ? '无损' : value === false ? '有损' : '未知'
}

function sampleRateLabel(value: number | null): string {
  return value === null ? '未知' : `${Number((value / 1000).toFixed(1))} kHz`
}

function channelsLabel(value: number | null): string {
  if (value === null) return '未知'
  if (value === 1) return '单声道'
  if (value === 2) return '双声道'
  return `${value} 声道`
}

function durationLabel(value: number | null): string {
  if (value === null) return '未知'
  const seconds = Math.max(0, Math.round(value / 1000))
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`
}

function formatPercent(value: number): string {
  return `${(value * 100).toFixed(1)}%`
}

function decisionLabel(value: MusicImportDecisionKind): string {
  return {
    createTrack: '新建曲目',
    replaceExistingTrack: '替换现有音频',
    keepExistingTrack: '保留现有曲目',
    treatAsSeparateRecording: '作为不同录音',
    rejectDuplicate: '拒绝重复文件',
    defer: '暂缓决定'
  }[value]
}
</script>

<style scoped>
.review-card {
  display: grid;
  gap: 16px;
  padding: 22px;
  color: rgba(255, 255, 255, 0.84);
  background: rgba(15, 23, 42, 0.64);
  border: 1px solid rgba(148, 163, 184, 0.2);
  border-radius: var(--radius-lg);
  box-shadow: 0 18px 48px rgba(3, 7, 18, 0.28);
}

.review-card__header,
.candidate__headline,
.decision-panel__heading,
.decision-panel__footer {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.review-card__index {
  color: #67e8f9;
  font: 700 10px/1.2 'SF Mono', ui-monospace, monospace;
  letter-spacing: 0.14em;
}

.review-card h2 {
  margin: 5px 0;
  color: #fff;
  font-size: 20px;
  overflow-wrap: anywhere;
}

.review-card__header p {
  margin: 0;
  color: rgba(255, 255, 255, 0.55);
}

.review-card__status {
  display: grid;
  justify-items: end;
  gap: 8px;
  white-space: nowrap;
  font: 12px/1.3 'SF Mono', ui-monospace, monospace;
}

.existing-track,
.match-facts {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px 14px;
  padding: 11px 13px;
  background: rgba(34, 211, 238, 0.06);
  border-left: 3px solid #22d3ee;
}

.existing-track span,
.match-facts {
  color: rgba(255, 255, 255, 0.55);
  font-size: 12px;
}

.existing-track small { color: rgba(255, 255, 255, 0.58); }

.candidate-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 300px), 1fr));
  gap: 12px;
}

.candidate {
  display: grid;
  align-content: start;
  gap: 13px;
  padding: 16px;
  background: rgba(255, 255, 255, 0.035);
  border: 1px solid rgba(255, 255, 255, 0.11);
  border-radius: var(--radius-md);
}

.candidate--recommended {
  background: linear-gradient(145deg, rgba(251, 191, 36, 0.08), rgba(255, 255, 255, 0.025));
  border-color: rgba(251, 191, 36, 0.44);
}

.candidate--selected {
  outline: 2px solid rgba(52, 211, 153, 0.72);
  outline-offset: -2px;
}

.candidate__name {
  display: grid;
  min-width: 0;
  gap: 4px;
}

.candidate__name strong,
.candidate__name span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.candidate__name span {
  color: rgba(255, 255, 255, 0.46);
  font: 11px/1.3 'SF Mono', ui-monospace, monospace;
}

.candidate__badges {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 5px;
}

.recommendation-badge,
.selection-badge,
.saved-decision {
  padding: 4px 7px;
  border-radius: 999px;
  font-size: 11px;
}

.recommendation-badge {
  color: #fde68a;
  background: rgba(180, 83, 9, 0.32);
  border: 1px solid rgba(251, 191, 36, 0.38);
}

.selection-badge,
.saved-decision {
  color: #a7f3d0;
  background: rgba(6, 95, 70, 0.36);
  border: 1px solid rgba(52, 211, 153, 0.38);
}

.quality-facts {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 9px;
  margin: 0;
}

.quality-facts div { min-width: 0; }
.quality-facts dt { color: rgba(255, 255, 255, 0.4); font-size: 10px; }
.quality-facts dd { margin: 2px 0 0; color: #fff; font-size: 12px; overflow-wrap: anywhere; }

.recommendation-copy {
  margin: 0;
  color: #fde68a;
  font-size: 12px;
  line-height: 1.6;
}

.candidate__controls {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.candidate__audio { width: 100%; height: 38px; }

.decision-panel {
  display: grid;
  gap: 14px;
  padding: 16px;
  background: rgba(2, 6, 23, 0.42);
  border: 1px solid rgba(129, 140, 248, 0.24);
  border-radius: var(--radius-md);
}

.decision-panel__heading > div { display: grid; gap: 3px; }
.decision-panel__heading span,
.decision-panel__footer > span { color: rgba(255, 255, 255, 0.47); font-size: 12px; }
.decision-options { display: flex; flex-wrap: wrap; gap: 6px 18px; }
.decision-options :deep(.el-radio) { margin-right: 0; color: rgba(255, 255, 255, 0.75); }

.review-error {
  display: grid;
  gap: 4px;
  padding: 10px 12px;
  color: #fecaca;
  background: rgba(127, 29, 29, 0.3);
  border-radius: var(--radius-sm);
}

@media (max-width: 767px) {
  .review-card { padding: 15px; }
  .review-card__header,
  .candidate__headline,
  .decision-panel__heading,
  .decision-panel__footer { align-items: stretch; flex-direction: column; }
  .review-card__status { justify-items: start; white-space: normal; }
  .candidate__badges { justify-content: flex-start; }
  .quality-facts { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .decision-panel__footer .el-button { width: 100%; }
}
</style>
