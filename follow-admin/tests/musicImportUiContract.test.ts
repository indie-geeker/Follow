import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

function readSource(relativePath: string): string {
  const url = new URL(`../src/${relativePath}`, import.meta.url)
  return existsSync(url) ? readFileSync(fileURLToPath(url), 'utf8') : ''
}

test('music import routes retain the tracks navigation context and page titles', () => {
  const router = readSource('router/index.ts')
  const layout = readSource('layouts/AdminLayout.vue')

  assert.match(router, /path:\s*['"]tracks\/imports['"]/)
  assert.match(router, /path:\s*['"]tracks\/imports\/new['"]/)
  assert.match(router, /path:\s*['"]tracks\/imports\/:jobId['"]/)
  assert.match(router, /path:\s*['"]tracks\/imports\/:jobId\/review['"]/)
  assert.equal(router.match(/activeMenu:\s*['"]\/tracks['"]/g)?.length, 4)
  assert.match(router, /title:\s*['"]音乐导入任务['"]/)
  assert.match(router, /title:\s*['"]创建导入任务['"]/)
  assert.match(router, /title:\s*['"]导入任务详情['"]/)
  assert.match(router, /title:\s*['"]重复曲目人工复核['"]/)
  assert.match(layout, /route\.meta\.activeMenu/)
  assert.match(layout, /route\.meta\.title/)
})

test('music import entry routes single-file upload into analysis review', () => {
  const tracks = readSource('views/music/TracksView.vue')
  const upload = readSource('api/upload.ts')
  const musicImports = readSource('api/musicImports.ts')

  assert.match(tracks, /初始化音乐库/)
  assert.match(tracks, /MusicImportCreate/)
  assert.match(tracks, /:http-request="uploadTrack"/)
  assert.match(tracks, /已提交分析，尚未入库/)
  assert.match(tracks, /MusicImportDetail|MusicImportReview/)
  assert.match(upload, /createMusicImportUpload/)
  assert.match(musicImports, /createMusicImportApi\(api\)/)
  assert.doesNotMatch(`${tracks}\n${upload}`, /\/api\/tracks\/upload/)
  assert.doesNotMatch(tracks, /tracks\.push\(/)
  const successHandler = tracks.match(/function handleUploadSuccess[\s\S]*?\n}/)?.[0] || ''
  assert.doesNotMatch(successHandler, /loadTracks\(/)
})

test('music import create view uses an idempotency key and server-mounted directory', () => {
  const source = readSource('views/music/imports/MusicImportCreateView.vue')

  assert.match(source, /crypto\.randomUUID\(\)/)
  assert.match(source, /relativeDirectory/)
  assert.match(source, /服务器挂载/)
  assert.match(source, /只读/)
  assert.match(source, /留空表示整个服务器挂载目录/)
  assert.doesNotMatch(source, /relativeDirectory\.trim\(\)\.length\s*>\s*0/)
  assert.doesNotMatch(source, /webkitdirectory|FileList|type="file"/)
  assert.match(source, /挂载根目录/)
})

test('directory initialization describes analysis as analysis rather than automatic import', () => {
  const create = readSource('views/music/imports/MusicImportCreateView.vue')
  const detail = readSource('views/music/imports/MusicImportDetailView.vue')

  assert.match(create, /扫描完成后自动开始相似分析/)
  assert.doesNotMatch(create, /扫描完成后自动开始导入/)
  assert.match(detail, /start:\s*['"]开始相似分析['"]/)
  assert.doesNotMatch(detail, /start:\s*['"]开始导入['"]/)
})

test('batch details distinguish browser staging from a mounted directory', () => {
  const types = readSource('types/musicImport.ts')
  const detail = readSource('views/music/imports/MusicImportDetailView.vue')

  assert.match(types, /interface MusicImportBatchSummary[\s\S]*sourceKind:\s*MusicImportSourceKind/)
  assert.match(detail, /browserStaging/)
  assert.match(detail, /浏览器上传暂存/)
  assert.match(detail, /服务器只读挂载/)
})

test('music import entry disables new directory work when fingerprint readiness fails', () => {
  const source = readSource('views/music/imports/MusicImportListView.vue')

  assert.match(source, /capabilities\.value\?\.canIngest/)
  assert.match(source, /fingerprintAvailable|fingerprintErrorCode/)
  assert.match(source, /声学指纹/)
})

test('music import detail view polls, paginates items, and exposes state actions', () => {
  const source = readSource('views/music/imports/MusicImportDetailView.vue')

  assert.match(source, /setInterval|schedulePoll|pollTimer/)
  assert.match(source, /listItems/)
  assert.match(source, /<AdminPagination\b/)
  assert.match(source, /getAvailableMusicImportActions/)
  assert.match(
    source,
    /getAvailableMusicImportActions\(batch\.value\.status, batch\.value\.progress\.retryableFailed\)/
  )
  assert.doesNotMatch(
    source,
    /getAvailableMusicImportActions\(batch\.value\.status, batch\.value\.progress\.failed\)/
  )
  assert.match(source, /Promise\.all\(\[loadBatch\(\), loadItems\(\)\]\)/)
  assert.match(source, /isTerminalStatus|stopPolling/)
  for (const action of ['start', 'pause', 'resume', 'cancel', 'retryFailures']) {
    assert.match(source, new RegExp(`musicImports\\.${action}\\(`))
  }
})

test('music import detail prevents stale reads and reports the real polling state', () => {
  const source = readSource('views/music/imports/MusicImportDetailView.vue')

  assert.match(source, /createLatestRequestGate/)
  assert.match(source, /batchRequestGate\.invalidate\(\)/)
  assert.match(source, /itemRequestGate\.invalidate\(\)/)
  assert.match(source, /setTimeout/)
  assert.doesNotMatch(source, /setInterval/)
  assert.match(source, /poll-state--active/)
  assert.match(source, /pollingStatusText/)
  assert.match(source, /自动同步已停止/)
})

test('music import pages keep API traffic behind the typed same-origin module', () => {
  const api = readSource('api/musicImports.ts')
  const pages = [
    'views/music/imports/MusicImportListView.vue',
    'views/music/imports/MusicImportCreateView.vue',
    'views/music/imports/MusicImportDetailView.vue'
  ].map(readSource).join('\n')

  assert.match(api, /import api from ['"]\.\/index(?:\.ts)?['"]/)
  assert.match(api, /createMusicImportApi\(api\)/)
  assert.doesNotMatch(api, /axios\.create|https?:\/\//)
  assert.match(pages, /@\/api\/musicImports/)
  assert.doesNotMatch(pages, /axios|fetch\(|VITE_API_URL|webkitdirectory|FileList/)
})

test('music import frontend types match the final server DTO field names', () => {
  const types = readSource('types/musicImport.ts')
  const pages = [
    'views/music/imports/MusicImportListView.vue',
    'views/music/imports/MusicImportCreateView.vue',
    'views/music/imports/MusicImportDetailView.vue'
  ].map(readSource).join('\n')

  for (const field of [
    'sourceAvailable',
    'sourceAlias',
    'processingConcurrency',
    'discoveredFileCount',
    'ignoredFileCount',
    'progress',
    'retryableFailed',
    'originalFileName',
    'sourceModifiedAt',
    'attemptCount',
    'retryable'
  ]) {
    assert.match(types, new RegExp(`\\b${field}\\b`))
  }

  assert.doesNotMatch(
    pages,
    /\.(?:sourceConfigured|sourceReadOnly|sourceLabel|completedItems|importedItems|attempts)\b/
  )
})
