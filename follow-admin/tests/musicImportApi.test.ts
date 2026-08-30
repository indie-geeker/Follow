import assert from 'node:assert/strict'
import { existsSync } from 'node:fs'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

interface RecordedCall {
  method: 'get' | 'post'
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
