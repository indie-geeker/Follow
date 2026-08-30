import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

function readProjectFile(relativePath: string): string {
  return readFileSync(fileURLToPath(new URL(`../${relativePath}`, import.meta.url)), 'utf8')
}

test('browser API traffic stays on the admin origin', () => {
  const api = readProjectFile('src/api/index.ts')

  assert.doesNotMatch(api, /VITE_API_URL|https?:\/\/localhost:\d+/)
  assert.doesNotMatch(api, /baseURL\s*:/)
  assert.match(api, /withCredentials\s*:\s*true/)
  assert.doesNotMatch(api, /Authorization|Bearer/)
})

test('development forwards relative API requests to the local server', () => {
  const config = readProjectFile('vite.config.ts')
  const developmentEnv = readProjectFile('.env.development')
  const productionEnv = readProjectFile('.env.production')

  assert.match(config, /proxy\s*:/)
  assert.match(config, /['"]\/api['"]\s*:/)
  assert.match(config, /FOLLOW_API_PROXY_TARGET/)
  assert.match(developmentEnv, /^FOLLOW_API_PROXY_TARGET=http:\/\/localhost:5050$/m)
  assert.doesNotMatch(developmentEnv, /VITE_API_URL/)
  assert.doesNotMatch(productionEnv, /VITE_API_URL/)
  assert.match(productionEnv, /同源/)
})

test('admin media and upload URLs are relative to the current origin', () => {
  for (const viewPath of [
    'src/views/music/TracksView.vue',
    'src/views/music/ArtistsView.vue',
    'src/views/music/AlbumsView.vue',
    'src/views/music/TagsView.vue'
  ]) {
    const source = readProjectFile(viewPath)
    assert.doesNotMatch(source, /VITE_API_URL|https?:\/\/localhost:\d+/)
  }

  const tracks = readProjectFile('src/views/music/TracksView.vue')
  const coverUrl = readProjectFile('src/utils/coverUrl.ts')
  assert.match(tracks, /\/api\/tracks\/upload/)
  assert.match(tracks, /toCoverProxyUrl/)
  assert.match(coverUrl, /\/api\/tracks\/cover\//)
})

test('file uploads use the replayable API client instead of raw upload requests', () => {
  const upload = readProjectFile('src/api/upload.ts')
  assert.match(upload, /api\.post/)

  for (const viewPath of [
    'src/views/music/TracksView.vue',
    'src/views/music/ArtistsView.vue',
    'src/views/music/AlbumsView.vue'
  ]) {
    const source = readProjectFile(viewPath)
    assert.match(source, /:http-request=/)
    assert.doesNotMatch(source, /:action=|:headers=/)
  }
})

test('audio preview gives the browser a same-origin stream URL', () => {
  const tracks = readProjectFile('src/views/music/TracksView.vue')

  assert.match(tracks, /streamUrl\.value\s*=\s*`\/api\/tracks\/\$\{track\.id\}\/stream`/)
  assert.doesNotMatch(tracks, /responseType\s*:\s*['"]blob['"]/)
  assert.doesNotMatch(tracks, /URL\.(?:create|revoke)ObjectURL/)
})

test('audio preview refreshes an expired cookie session once before reporting failure', () => {
  const tracks = readProjectFile('src/views/music/TracksView.vue')

  assert.match(tracks, /playbackRefreshAttempted/)
  assert.match(tracks, /async function handlePlaybackError/)
  assert.match(tracks, /await refreshSession\(\)/)
})
