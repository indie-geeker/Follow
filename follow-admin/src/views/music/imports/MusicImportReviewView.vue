<template>
  <div class="review-page">
    <nav class="review-nav" aria-label="审核页面导航">
      <el-button link @click="router.push({ name: 'MusicImportDetail', params: { jobId: batchId } })">
        <el-icon><ArrowLeft /></el-icon>
        返回任务详情
      </el-button>
      <span>批次 {{ batchId.slice(0, 8).toUpperCase() }}</span>
    </nav>

    <section class="review-hero">
      <div>
        <span class="review-hero__eyebrow">ACOUSTIC REVIEW DESK</span>
        <h1>重复曲目人工复核</h1>
        <p>系统只标记相似和质量更优的候选，不会自动选择、替换或入库。每一组都需要管理员明确决定。</p>
      </div>
      <div class="review-hero__actions">
        <el-button :loading="bulkBusy" :disabled="!canBulkRecommend" @click="acceptRecommendations">
          批量采用系统建议
        </el-button>
        <el-button type="primary" :loading="applyBusy" :disabled="applyDisabled" @click="applyAll">
          确认应用全部决定
        </el-button>
      </div>
    </section>

    <div v-if="errorMessage" class="review-notice review-notice--error" role="alert">
      <span>{{ errorMessage }}</span>
      <el-button link type="danger" @click="loadPage">重新加载</el-button>
    </div>

    <section v-if="reviewPage" class="review-summary" aria-label="审核进度">
      <div><span>待决定</span><strong>{{ reviewPage.summary.open }}</strong></div>
      <div><span>已确认</span><strong>{{ reviewPage.summary.confirmed }}</strong></div>
      <div><span>已暂缓</span><strong>{{ reviewPage.summary.deferred }}</strong></div>
      <div><span>已应用</span><strong>{{ reviewPage.summary.applied }}</strong></div>
      <p role="status" aria-live="polite">
        共 {{ reviewPage.totalCount }} 组；存在待决定或暂缓组时不能应用。
      </p>
    </section>

    <div v-loading="loading" class="review-groups" aria-live="polite">
      <MusicImportReviewGroupCard
        v-for="(group, index) in reviewPage?.groups || []"
        :key="group.id"
        :group="group"
        :draft="draftFor(group)"
        :sequence="(pagination.page - 1) * pagination.pageSize + index + 1"
        :busy="savingGroupId === group.id"
        @decision-change="setDecision(group, $event)"
        @candidate-change="setCandidate(group, $event)"
        @save="saveGroup(group)"
      />
      <div v-if="!loading && reviewPage?.totalCount === 0" class="review-empty" role="status">
        当前任务尚未生成需要人工复核的候选组。
      </div>
    </div>

    <AdminPagination
      v-if="reviewPage && reviewPage.totalCount > pagination.pageSize"
      v-model:current-page="pagination.page"
      :page-size="pagination.pageSize"
      :total="reviewPage.totalCount"
      @current-change="loadPage"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { ArrowLeft } from '@element-plus/icons-vue'
import musicImports from '@/api/musicImports'
import AdminPagination from '@/components/AdminPagination.vue'
import MusicImportReviewGroupCard from './MusicImportReviewGroupCard.vue'
import type {
  MusicImportDecisionKind,
  MusicImportReviewGroup,
  MusicImportReviewPage
} from '@/types/musicImport'
import {
  buildApplyRequest,
  buildDecisionRequest,
  canApplyReviewSummary,
  createReviewDecisionDraft,
  normalizeReviewConflict,
  type MusicImportReviewDecisionDraft
} from '@/utils/musicImportReview'
import { getApiErrorMessage } from '@/utils/apiError'

const route = useRoute()
const router = useRouter()
const batchId = String(route.params.jobId)
const reviewPage = ref<MusicImportReviewPage | null>(null)
const loading = ref(false)
const bulkBusy = ref(false)
const applyBusy = ref(false)
const savingGroupId = ref<string | null>(null)
const errorMessage = ref('')
const pagination = reactive({ page: 1, pageSize: 10 })
const drafts = reactive<Record<string, MusicImportReviewDecisionDraft>>({})

const applyDisabled = computed(() => {
  const page = reviewPage.value
  if (!page || applyBusy.value || page.totalCount === 0) return true
  return !canApplyReviewSummary(page.summary, page.totalCount)
})

const canBulkRecommend = computed(() => Boolean(
  reviewPage.value &&
  !bulkBusy.value &&
  (reviewPage.value.summary.open > 0 || reviewPage.value.summary.deferred > 0)
))

async function loadPage() {
  loading.value = true
  errorMessage.value = ''
  try {
    const response = await musicImports.listReviewGroups(batchId, {
      page: pagination.page,
      pageSize: pagination.pageSize
    })
    reviewPage.value = response
    for (const group of response.groups) {
      drafts[group.id] = createReviewDecisionDraft(group)
    }
  } catch (error) {
    errorMessage.value = getApiErrorMessage(error, '审核候选加载失败')
  } finally {
    loading.value = false
  }
}

function draftFor(group: MusicImportReviewGroup): MusicImportReviewDecisionDraft {
  const existing = drafts[group.id]
  if (existing) return existing
  const created = createReviewDecisionDraft(group)
  drafts[group.id] = created
  return created
}

function setDecision(group: MusicImportReviewGroup, decisionKind: MusicImportDecisionKind) {
  const draft = draftFor(group)
  draft.decisionKind = decisionKind
  if (decisionKind !== 'createTrack' && decisionKind !== 'replaceExistingTrack') {
    draft.candidateId = null
  }
}

function setCandidate(group: MusicImportReviewGroup, candidateId: string) {
  draftFor(group).candidateId = candidateId
}

async function saveGroup(group: MusicImportReviewGroup) {
  if (savingGroupId.value) return
  savingGroupId.value = group.id
  try {
    const request = buildDecisionRequest(group, draftFor(group))
    const updated = await musicImports.saveReviewDecision(group.id, request)
    replaceVisibleGroup(updated)
    drafts[group.id] = createReviewDecisionDraft(updated)
    ElMessage.success('本组决定已保存')
    await loadPage()
  } catch (error) {
    const current = normalizeReviewConflict(error)
    if (current) {
      replaceVisibleGroup(current)
      drafts[current.id] = createReviewDecisionDraft(current)
      await loadPage()
      ElMessage.warning('该审核组已被其他页面修改，已刷新为服务器最新版本')
    } else {
      ElMessage.error(getApiErrorMessage(error, '审核决定保存失败'))
    }
  } finally {
    savingGroupId.value = null
  }
}

async function acceptRecommendations() {
  try {
    await ElMessageBox.confirm(
      '将批量采用所有仍待处理组的系统建议：有现有曲目的组会替换音频，其余组会新建曲目。此操作只保存审核决定，仍需再次确认应用。是否继续？',
      '批量采用系统建议',
      { confirmButtonText: '明确采用建议', cancelButtonText: '返回逐组审核', type: 'warning' }
    )
  } catch {
    return
  }

  bulkBusy.value = true
  try {
    const groups = await loadAllGroups()
    const targets = groups.filter(group =>
      (group.status === 'open' || group.status === 'deferred') && group.recommendedItemId)
    if (targets.length === 0) throw new Error('没有可采用的系统建议。')

    for (const group of targets) {
      const request = buildDecisionRequest(group, {
        decisionKind: group.existingTrackId ? 'replaceExistingTrack' : 'createTrack',
        candidateId: group.recommendedItemId
      })
      await musicImports.saveReviewDecision(group.id, request)
    }
    ElMessage.success(`已明确采用 ${targets.length} 组建议；尚未入库`)
    await loadPage()
  } catch (error) {
    const current = normalizeReviewConflict(error)
    if (current) {
      replaceVisibleGroup(current)
      drafts[current.id] = createReviewDecisionDraft(current)
      await loadPage()
      ElMessage.warning('批量保存遇到版本冲突，已刷新冲突组，请复核后重试')
    } else {
      ElMessage.error(getApiErrorMessage(error, '批量采用建议失败'))
    }
  } finally {
    bulkBusy.value = false
  }
}

async function applyAll() {
  try {
    await ElMessageBox.confirm(
      '应用后才会按已保存决定新建曲目或替换音频。请确认每一组均为你的明确选择。',
      '确认应用全部决定',
      { confirmButtonText: '确认应用并入库', cancelButtonText: '继续检查', type: 'warning' }
    )
  } catch {
    return
  }

  applyBusy.value = true
  try {
    const groups = await loadAllGroups()
    const request = buildApplyRequest(groups, reviewPage.value?.totalCount ?? 0)
    await musicImports.applyReview(batchId, request)
    ElMessage.success('全部决定已锁定，正在按确认结果入库')
    await router.push({ name: 'MusicImportDetail', params: { jobId: batchId } })
  } catch (error) {
    const current = normalizeReviewConflict(error)
    if (current) {
      replaceVisibleGroup(current)
      drafts[current.id] = createReviewDecisionDraft(current)
      await loadPage()
      ElMessage.warning('应用前发现版本冲突，已刷新冲突组')
    } else {
      ElMessage.error(getApiErrorMessage(error, '应用审核决定失败'))
    }
  } finally {
    applyBusy.value = false
  }
}

async function loadAllGroups(): Promise<MusicImportReviewGroup[]> {
  const first = await musicImports.listReviewGroups(batchId, { page: 1, pageSize: 100 })
  const all = [...first.groups]
  for (let page = 2; page <= first.totalPages; page += 1) {
    const next = await musicImports.listReviewGroups(batchId, { page, pageSize: 100 })
    all.push(...next.groups)
  }
  if (all.length !== first.totalCount) throw new Error('未能加载全部审核组，请刷新后重试。')
  return all
}

function replaceVisibleGroup(updated: MusicImportReviewGroup) {
  if (!reviewPage.value) return
  reviewPage.value.groups = reviewPage.value.groups.map(group =>
    group.id === updated.id ? updated : group)
}

onMounted(loadPage)
</script>

<style scoped>
.review-page {
  display: grid;
  gap: 18px;
  animation: reviewIn 0.32s ease-out;
}

@keyframes reviewIn {
  from { opacity: 0; transform: translateY(6px); }
  to { opacity: 1; transform: translateY(0); }
}

.review-nav,
.review-hero,
.review-summary {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.review-nav { color: rgba(255, 255, 255, 0.48); font: 12px/1.3 'SF Mono', ui-monospace, monospace; }

.review-hero {
  padding: 24px;
  color: #fff;
  background:
    radial-gradient(circle at 85% 10%, rgba(34, 211, 238, 0.13), transparent 30%),
    linear-gradient(145deg, rgba(79, 70, 229, 0.2), rgba(15, 23, 42, 0.64));
  border: 1px solid rgba(129, 140, 248, 0.28);
  border-radius: var(--radius-lg);
  box-shadow: 0 18px 48px rgba(3, 7, 18, 0.3);
}

.review-hero__eyebrow { color: #67e8f9; font: 700 10px/1.2 'SF Mono', ui-monospace, monospace; letter-spacing: 0.14em; }
.review-hero h1 { margin: 6px 0; font-size: clamp(24px, 3vw, 32px); }
.review-hero p { max-width: 760px; margin: 0; color: rgba(255, 255, 255, 0.61); line-height: 1.65; }
.review-hero__actions { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 8px; }
.review-hero__actions .el-button { margin: 0; }

.review-summary {
  display: grid;
  grid-template-columns: repeat(4, minmax(100px, 1fr)) minmax(240px, 2fr);
  padding: 14px 18px;
  color: #fff;
  background: rgba(15, 23, 42, 0.5);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: var(--radius-md);
}

.review-summary div { display: grid; gap: 2px; }
.review-summary span { color: rgba(255, 255, 255, 0.48); font-size: 11px; }
.review-summary strong { font: 700 22px/1 'SF Mono', ui-monospace, monospace; }
.review-summary p { margin: 0; color: rgba(255, 255, 255, 0.58); font-size: 12px; line-height: 1.5; }

.review-groups { display: grid; min-height: 120px; gap: 14px; }
.review-empty { padding: 40px; color: rgba(255, 255, 255, 0.54); text-align: center; }
.review-notice { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 12px 15px; border-radius: var(--radius-md); }
.review-notice--error { color: #fecaca; background: rgba(127, 29, 29, 0.34); border: 1px solid rgba(248, 113, 113, 0.32); }

@media (max-width: 767px) {
  .review-nav,
  .review-hero { align-items: stretch; flex-direction: column; }
  .review-hero { padding: 18px; }
  .review-hero__actions,
  .review-hero__actions .el-button { width: 100%; }
  .review-summary { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .review-summary p { grid-column: 1 / -1; }
}
</style>
