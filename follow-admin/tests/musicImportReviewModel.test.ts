import assert from 'node:assert/strict'
import { existsSync } from 'node:fs'
import test from 'node:test'

async function loadReviewModel() {
  const moduleUrl = new URL('../src/utils/musicImportReview.ts', import.meta.url)
  assert.ok(existsSync(moduleUrl), 'music import review model should exist')
  return import(moduleUrl.href)
}

function group(overrides: Record<string, unknown> = {}) {
  const candidate = {
    id: 'candidate-id',
    version: 0,
    relativePath: 'safe/song.flac',
    sourceLabel: 'safe/song.flac',
    originalFileName: 'song.flac',
    sourceKind: 'mountedDirectory',
    extractedTitle: 'Song',
    extractedArtist: 'Artist',
    extractedAlbum: 'Album',
    codec: 'flac',
    container: 'flac',
    isLossless: true,
    sampleRateHz: 96000,
    bitDepth: 24,
    channels: 2,
    bitRateKbps: 2400,
    sizeBytes: 3145728,
    exactDurationMilliseconds: 180000,
    decision: null,
    decisionTrackId: null,
    previewAvailable: true,
    previewUrl: '/api/admin/music-imports/items/candidate-id/preview'
  }
  return {
    id: 'group-id',
    batchId: 'batch-id',
    status: 'open',
    matchKind: 'acousticFingerprint',
    matchExplanation: '声学指纹相似度 98.7%',
    version: 7,
    existingTrackId: null,
    existingTrack: null,
    recommendedItemId: candidate.id,
    recommendationExplanation: '无损格式且采样率更高',
    fingerprintVersion: 'fpcalc 1.6.1',
    fingerprintAlgorithm: 2,
    overallSimilarity: 0.987,
    minimumSegmentSimilarity: 0.95,
    coverageFraction: 0.91,
    alignmentOffsetFrames: 2,
    confirmedByUserId: null,
    confirmedAt: null,
    decisionKind: null,
    selectedItemIds: [],
    applyErrorCode: null,
    applyErrorMessage: null,
    cleanupStatus: null,
    cleanupErrorCode: null,
    cleanupErrorMessage: null,
    candidates: [candidate],
    ...overrides
  }
}

test('review form never converts a recommendation into a default selection', async () => {
  const { createReviewDecisionDraft } = await loadReviewModel()

  assert.deepEqual(createReviewDecisionDraft(group()), {
    decisionKind: null,
    candidateId: null
  })
})

test('quality and recommendation labels state facts without claiming approval', async () => {
  const { formatCandidateQuality, recommendationDisplay } = await loadReviewModel()
  const candidate = group().candidates[0]

  assert.equal(
    formatCandidateQuality(candidate),
    'FLAC · 无损 · 96 kHz · 24-bit · 双声道 · 2400 kbps · 3 MB · 3:00'
  )
  assert.equal(
    recommendationDisplay(group()),
    '系统建议：song.flac（无损格式且采样率更高）'
  )
})

test('decision validation requires the exact user choice and existing Track when needed', async () => {
  const { buildDecisionRequest } = await loadReviewModel()
  const fixture = group()

  assert.throws(
    () => buildDecisionRequest(fixture, { decisionKind: 'createTrack', candidateId: null }),
    /候选文件/
  )
  assert.throws(
    () => buildDecisionRequest(fixture, {
      decisionKind: 'replaceExistingTrack',
      candidateId: 'candidate-id'
    }),
    /现有曲目/
  )
  assert.deepEqual(
    buildDecisionRequest(fixture, {
      decisionKind: 'createTrack',
      candidateId: 'candidate-id'
    }),
    {
      expectedVersion: 7,
      decisionKind: 'createTrack',
      selectedItemIds: ['candidate-id']
    }
  )
})

test('apply payload is complete and rejects unresolved or omitted groups', async () => {
  const { buildApplyRequest, canApplyReviewSummary } = await loadReviewModel()
  const confirmedOne = group({ id: 'one', version: 3, status: 'confirmed' })
  const confirmedTwo = group({ id: 'two', version: 8, status: 'confirmed' })
  const applied = group({ id: 'done', version: 9, status: 'applied' })

  assert.deepEqual(buildApplyRequest([confirmedOne, confirmedTwo], 2), {
    groups: [
      { groupId: 'one', expectedVersion: 3 },
      { groupId: 'two', expectedVersion: 8 }
    ]
  })
  assert.throws(() => buildApplyRequest([confirmedOne], 2), /全部审核组/)
  assert.throws(
    () => buildApplyRequest([confirmedOne, group({ id: 'open', status: 'open' })], 2),
    /尚未确认/
  )
  assert.deepEqual(buildApplyRequest([applied, confirmedOne], 2), {
    groups: [
      { groupId: 'done', expectedVersion: 9 },
      { groupId: 'one', expectedVersion: 3 }
    ]
  })
  assert.throws(() => buildApplyRequest([applied], 1), /没有待应用/)
  assert.equal(canApplyReviewSummary({
    open: 0,
    confirmed: 1,
    locked: 0,
    applied: 1,
    deferred: 0,
    conflict: 0,
    failed: 0
  }, 2), true)
})

test('stale conflict normalizes the current server group for refresh', async () => {
  const { normalizeReviewConflict } = await loadReviewModel()
  const current = group({ version: 8 })

  assert.deepEqual(normalizeReviewConflict({ response: { status: 409, data: current } }), current)
  assert.equal(normalizeReviewConflict({ response: { status: 500, data: current } }), null)
})

test('only decisions that ingest candidate audio render file-selection badges', async () => {
  const { canTreatAsSeparateRecording, isFileSelectionDecision } = await loadReviewModel()

  assert.equal(isFileSelectionDecision('createTrack'), true)
  assert.equal(isFileSelectionDecision('replaceExistingTrack'), true)
  assert.equal(isFileSelectionDecision('treatAsSeparateRecording'), true)
  assert.equal(isFileSelectionDecision('keepExistingTrack'), false)
  assert.equal(isFileSelectionDecision('rejectDuplicate'), false)
  assert.equal(isFileSelectionDecision('defer'), false)
  assert.equal(isFileSelectionDecision(null), false)
  assert.equal(canTreatAsSeparateRecording('exactSha256'), false)
  assert.equal(canTreatAsSeparateRecording('acousticFingerprint'), true)
  assert.equal(canTreatAsSeparateRecording('none'), true)
})
