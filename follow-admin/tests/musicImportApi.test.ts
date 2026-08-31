import assert from 'node:assert/strict'
import { existsSync } from 'node:fs'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

interface RecordedCall {
  method: 'get' | 'post' | 'put'
  url: string
  payload?: unknown
  config?: unknown
}

function apiModuleUrl(): URL {
  return new URL('../src/api/musicImportClient.ts', import.meta.url)
}

async function loadMusicImportApi() {
  const moduleUrl = apiModuleUrl()
  assert.ok(existsSync(moduleUrl), 'music import typed API client should exist')
  return import(moduleUrl.href)
}

async function loadMusicImportTypes() {
  const moduleUrl = new URL('../src/types/musicImport.ts', import.meta.url)
  assert.ok(existsSync(moduleUrl), 'music import types module should exist')
  return import(moduleUrl.href)
}

function createRecordingClient(calls: RecordedCall[]) {
  return {
    async get(url: string, config?: unknown) {
      calls.push({ method: 'get' as const, url, config })
      return { data: { marker: url } }
    },
    async post(url: string, payload?: unknown) {
      calls.push({ method: 'post' as const, url, payload })
      return { data: { marker: url } }
    },
    async put(url: string, payload?: unknown) {
      calls.push({ method: 'put' as const, url, payload })
      return { data: { marker: url } }
    }
  }
}

test('music import API uses the shared same-origin client contract', async () => {
  const { createMusicImportApi } = await loadMusicImportApi()
  const calls: RecordedCall[] = []
  const musicImports = createMusicImportApi(createRecordingClient(calls))

  await musicImports.getCapabilities()
  await musicImports.listBatches({ page: 2, pageSize: 20, status: 'running' })
  await musicImports.createBatch({
    clientRequestId: 'request-id',
    relativeDirectory: 'family-library',
    autoStart: false
  })
  await musicImports.getBatch('batch-id')
  await musicImports.listItems('batch-id', { page: 3, pageSize: 50, status: 'failed' })

  assert.deepEqual(calls, [
    { method: 'get', url: '/api/admin/music-imports/capabilities', config: undefined },
    {
      method: 'get',
      url: '/api/admin/music-imports',
      config: { params: { page: 2, pageSize: 20, status: 'running' } }
    },
    {
      method: 'post',
      url: '/api/admin/music-imports',
      payload: {
        clientRequestId: 'request-id',
        relativeDirectory: 'family-library',
        autoStart: false
      }
    },
    { method: 'get', url: '/api/admin/music-imports/batch-id', config: undefined },
    {
      method: 'get',
      url: '/api/admin/music-imports/batch-id/items',
      config: { params: { page: 3, pageSize: 50, status: 'failed' } }
    }
  ])
})

test('music import review API sends exact versions and paged review requests', async () => {
  const { createMusicImportApi } = await loadMusicImportApi()
  const calls: RecordedCall[] = []
  const reviewGroup = reviewGroupFixture()
  const client = {
    async get(url: string, config?: unknown) {
      calls.push({ method: 'get' as const, url, config })
      if (url.endsWith('/review-groups/group-id')) return { data: reviewGroup }
      return {
        data: {
          batchId: 'batch-id',
          status: 'awaitingReview',
          version: 4,
          summary: { open: 1, confirmed: 0, locked: 0, applied: 0, deferred: 0, conflict: 0, failed: 0 },
          groups: [reviewGroup],
          totalCount: 1,
          page: 2,
          pageSize: 10,
          totalPages: 1
        }
      }
    },
    async post(url: string, payload?: unknown) {
      calls.push({ method: 'post' as const, url, payload })
      return { data: { id: 'batch-id', status: 'readyToApply', version: 5 } }
    },
    async put(url: string, payload?: unknown) {
      calls.push({ method: 'put' as const, url, payload })
      return { data: reviewGroup }
    }
  }
  const musicImports = createMusicImportApi(client)

  const page = await musicImports.listReviewGroups('batch-id', { page: 2, pageSize: 10 })
  const group = await musicImports.getReviewGroup('group-id')
  await musicImports.saveReviewDecision('group-id', {
    expectedVersion: 7,
    decisionKind: 'createTrack',
    selectedItemIds: ['candidate-id']
  })
  await musicImports.applyReview('batch-id', {
    groups: [{ groupId: 'group-id', expectedVersion: 8 }]
  })

  assert.equal(page.groups[0]?.status, 'open')
  assert.equal(group.candidates[0]?.codec, 'flac')
  assert.deepEqual(calls, [
    {
      method: 'get',
      url: '/api/admin/music-imports/batch-id/review-groups',
      config: { params: { page: 2, pageSize: 10 } }
    },
    {
      method: 'get',
      url: '/api/admin/music-imports/review-groups/group-id',
      config: undefined
    },
    {
      method: 'put',
      url: '/api/admin/music-imports/review-groups/group-id/decision',
      payload: {
        expectedVersion: 7,
        decisionKind: 'createTrack',
        selectedItemIds: ['candidate-id']
      }
    },
    {
      method: 'post',
      url: '/api/admin/music-imports/batch-id/apply',
      payload: { groups: [{ groupId: 'group-id', expectedVersion: 8 }] }
    }
  ])
})

test('music import review response parsing rejects unknown enum values', async () => {
  const { parseMusicImportReviewGroup } = await loadMusicImportApi()
  const fixture = reviewGroupFixture()

  assert.equal(parseMusicImportReviewGroup(fixture).matchKind, 'acousticFingerprint')
  assert.throws(
    () => parseMusicImportReviewGroup({ ...fixture, status: 'automaticallyAccepted' }),
    /review status/i
  )
  assert.throws(
    () => parseMusicImportReviewGroup({ ...fixture, matchKind: 'metadataGuess' }),
    /match kind/i
  )
})

test('browser upload uses staging ingestion and requires a 202 review task response', async () => {
  const { createMusicImportApi } = await loadMusicImportApi()
  const calls: Array<{ url: string; data: unknown; config: unknown }> = []
  const client = {
    async get() { throw new Error('unexpected get') },
    async put() { throw new Error('unexpected put') },
    async post(url: string, data?: unknown, config?: unknown) {
      calls.push({ url, data, config })
      return {
        status: 202,
        data: { batchId: 'batch-id', itemId: 'item-id', status: 'analyzing' }
      }
    }
  }
  const api = createMusicImportApi(client)
  const file = new File(['audio'], 'song.flac', { type: 'audio/flac' })

  const accepted = await api.uploadBrowserFile(file, 'request-id')

  assert.deepEqual(accepted, { batchId: 'batch-id', itemId: 'item-id', status: 'analyzing' })
  assert.equal(calls[0]?.url, '/api/admin/music-imports/uploads')
  assert.ok(calls[0]?.data instanceof FormData)
  assert.deepEqual(calls[0]?.config, { params: { clientRequestId: 'request-id' } })
})

test('music import API exposes every audited batch action', async () => {
  const { createMusicImportApi } = await loadMusicImportApi()
  const calls: RecordedCall[] = []
  const musicImports = createMusicImportApi(createRecordingClient(calls))

  await musicImports.start('batch-id')
  await musicImports.pause('batch-id')
  await musicImports.resume('batch-id')
  await musicImports.cancel('batch-id')
  await musicImports.retryFailures('batch-id')

  assert.deepEqual(calls, [
    { method: 'post', url: '/api/admin/music-imports/batch-id/start', payload: undefined },
    { method: 'post', url: '/api/admin/music-imports/batch-id/pause', payload: undefined },
    { method: 'post', url: '/api/admin/music-imports/batch-id/resume', payload: undefined },
    { method: 'post', url: '/api/admin/music-imports/batch-id/cancel', payload: undefined },
    { method: 'post', url: '/api/admin/music-imports/batch-id/retry-failures', payload: undefined }
  ])
})

test('music import actions require retryable failures in the durable batch state', async () => {
  const { getAvailableMusicImportActions } = await loadMusicImportApi()

  assert.deepEqual(getAvailableMusicImportActions('ready', 0), ['start', 'cancel'])
  assert.deepEqual(getAvailableMusicImportActions('running', 0), ['pause', 'cancel'])
  assert.deepEqual(getAvailableMusicImportActions('pauseRequested', 0), ['cancel'])
  assert.deepEqual(getAvailableMusicImportActions('paused', 0), ['resume', 'cancel'])
  assert.deepEqual(getAvailableMusicImportActions('completedWithErrors', 4), ['retryFailures'])
  assert.deepEqual(getAvailableMusicImportActions('completedWithErrors', 0), [])
  assert.deepEqual(getAvailableMusicImportActions('completed', 0), [])
})

test('music import summaries expose stable labels, byte sizes, and progress', async () => {
  const {
    calculateMusicImportProgress,
    formatMusicImportBytes,
    musicImportBatchStatusLabel
  } = await loadMusicImportTypes()

  assert.equal(formatMusicImportBytes(0), '0 B')
  assert.equal(formatMusicImportBytes(1536), '1.5 KB')
  assert.equal(formatMusicImportBytes(5 * 1024 * 1024 * 1024), '5 GB')
  assert.equal(musicImportBatchStatusLabel('pauseRequested'), '正在暂停')
  assert.equal(musicImportBatchStatusLabel('completedWithErrors'), '完成但有错误')
  assert.equal(calculateMusicImportProgress({
    discoveredFileCount: 0,
    progress: { imported: 0, duplicate: 0, skipped: 0, failed: 0, cancelled: 0 }
  }), 0)
  assert.equal(calculateMusicImportProgress({
    discoveredFileCount: 10,
    progress: { imported: 2, duplicate: 1, skipped: 0, failed: 1, cancelled: 0 }
  }), 40)
  assert.equal(calculateMusicImportProgress({
    discoveredFileCount: 3,
    progress: { imported: 4, duplicate: 1, skipped: 1, failed: 1, cancelled: 0 }
  }), 100)
})

function reviewGroupFixture() {
  return {
    id: 'group-id',
    batchId: 'batch-id',
    status: 'open',
    matchKind: 'acousticFingerprint',
    matchExplanation: '声学指纹相似度 98.7%',
    version: 7,
    existingTrackId: null,
    existingTrack: null,
    recommendedItemId: 'candidate-id',
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
    candidates: [{
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
    }]
  }
}
