import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

function readSource(relativePath: string): string {
  const url = new URL(`../src/${relativePath}`, import.meta.url)
  return existsSync(url) ? readFileSync(fileURLToPath(url), 'utf8') : ''
}

test('review route and import pages expose the manual review entry', () => {
  const router = readSource('router/index.ts')
  const detail = readSource('views/music/imports/MusicImportDetailView.vue')
  const list = readSource('views/music/imports/MusicImportListView.vue')

  assert.match(router, /path:\s*['"]tracks\/imports\/:jobId\/review['"]/)
  assert.match(router, /MusicImportReviewView\.vue/)
  assert.match(detail, /MusicImportReview/)
  assert.match(list, /MusicImportReview/)
  assert.match(`${detail}\n${list}`, /人工复核/)
})

test('review group card shows complete quality, match, source, and lazy preview facts', () => {
  const source = readSource('views/music/imports/MusicImportReviewGroupCard.vue')

  for (const fact of [
    'container',
    'codec',
    'isLossless',
    'sampleRateHz',
    'bitDepth',
    'channels',
    'bitRateKbps',
    'sizeBytes',
    'exactDurationMilliseconds',
    'sourceLabel',
    'overallSimilarity',
    'matchExplanation'
  ]) {
    assert.match(source, new RegExp(`\\b${fact}\\b`))
  }
  assert.match(source, /系统建议/)
  assert.match(source, /管理员已选择/)
  assert.match(source, /preload=["']none["']/)
  assert.match(source, /previewAvailable/)
  assert.match(source, /previewUrl/)
  assert.match(source, /aria-label/)
  assert.doesNotMatch(source, /:model-value=["']group\.recommendedItemId["']/)
  assert.doesNotMatch(source, /draft\.candidateId\s*=\s*group\.recommendedItemId/)
})

test('review view requires explicit decisions and confirmation before bulk or apply', () => {
  const source = [
    readSource('views/music/imports/MusicImportReviewView.vue'),
    readSource('views/music/imports/MusicImportReviewGroupCard.vue')
  ].join('\n')

  for (const action of [
    'createTrack',
    'replaceExistingTrack',
    'keepExistingTrack',
    'treatAsSeparateRecording',
    'rejectDuplicate',
    'defer'
  ]) {
    assert.match(source, new RegExp(`['"]${action}['"]`))
  }
  assert.match(source, /createReviewDecisionDraft/)
  assert.match(source, /buildDecisionRequest/)
  assert.match(source, /buildApplyRequest/)
  assert.match(source, /normalizeReviewConflict/)
  assert.match(source, /ElMessageBox\.confirm/)
  assert.match(source, /批量采用系统建议/)
  assert.match(source, /确认应用全部决定/)
  assert.match(source, /applyDisabled/)
  assert.match(source, /summary\.open|summary\.deferred/)
  assert.match(source, /v-if=["']canTreatAsSeparateRecording\(group\.matchKind\)["']/)
  assert.match(source, /listReviewGroups/)
  assert.match(source, /<AdminPagination\b/)
  assert.match(source, /role=["'](?:status|alert)["']/)
  assert.doesNotMatch(source, /drafts\[group\.id\]\.candidateId\s*=\s*group\.recommendedItemId/)
})

test('stale review conflicts refresh group data and the page summary together', () => {
  const source = readSource('views/music/imports/MusicImportReviewView.vue')
  const conflictBranches = source.match(/if \(current\) \{[\s\S]*?\n\s*\} else \{/g) || []

  assert.ok(conflictBranches.length >= 3, 'save, bulk, and apply conflicts should be handled')
  for (const branch of conflictBranches) {
    assert.match(branch, /await loadPage\(\)/)
  }
})

test('review layout includes narrow-screen and long-filename safeguards', () => {
  const card = readSource('views/music/imports/MusicImportReviewGroupCard.vue')
  const styles = readSource('styles/admin-components.css')

  assert.match(card, /overflow-wrap:\s*anywhere|text-overflow:\s*ellipsis/)
  assert.match(`${card}\n${styles}`, /@media\s*\(max-width:\s*767px\)/)
})
