import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

import { normalizeCoverObjectKey, toCoverProxyUrl } from '../src/utils/coverUrl.ts'

function readSource(relativePath: string): string {
  return readFileSync(fileURLToPath(new URL(`../src/${relativePath}`, import.meta.url)), 'utf8')
}

test('builds same-origin cover URLs by encoding each object-key segment', () => {
  assert.equal(
    toCoverProxyUrl('covers/family album/封面.jpg'),
    '/api/tracks/cover/covers/family%20album/%E5%B0%81%E9%9D%A2.jpg'
  )
  assert.equal(
    toCoverProxyUrl('artists/artist-id/PORTRAIT.WEBP'),
    '/api/tracks/cover/artists/artist-id/PORTRAIT.WEBP'
  )
  assert.equal(
    toCoverProxyUrl('albums/album-id/cover.gif'),
    '/api/tracks/cover/albums/album-id/cover.gif'
  )
})

test('accepts only guarded MinIO image object keys', () => {
  assert.equal(normalizeCoverObjectKey('  covers/id/cover.jpeg  '), 'covers/id/cover.jpeg')

  for (const unsafeValue of [
    'https://example.com/cover.jpg',
    'http://example.com/cover.jpg',
    '//example.com/cover.jpg',
    '/covers/id/cover.jpg',
    'covers/../secret.jpg',
    'covers/./cover.jpg',
    'covers\\id\\cover.jpg',
    'covers//cover.jpg',
    'tracks/id/cover.jpg',
    'tags/id/cover.jpg',
    'covers/id/cover.svg',
    'covers/id/cover.jpg?download=1',
    'covers/id/'
  ]) {
    assert.equal(normalizeCoverObjectKey(unsafeValue), null, unsafeValue)
    assert.equal(toCoverProxyUrl(unsafeValue), '', unsafeValue)
  }
})

test('music views share the guarded helper and expose no arbitrary cover URL input', () => {
  const views = [
    'views/music/TracksView.vue',
    'views/music/ArtistsView.vue',
    'views/music/AlbumsView.vue',
    'views/music/TagsView.vue'
  ]

  for (const view of views) {
    const source = readSource(view)
    assert.match(source, /toCoverProxyUrl/)
    assert.doesNotMatch(source, /function getCoverUrl|startsWith\(['"]http['"]\)/)
  }

  const artists = readSource('views/music/ArtistsView.vue')
  const albums = readSource('views/music/AlbumsView.vue')
  const tags = readSource('views/music/TagsView.vue')
  const tracks = readSource('views/music/TracksView.vue')

  assert.doesNotMatch(artists, /<el-input[^>]*v-model="form\.coverUrl"/)
  assert.doesNotMatch(albums, /<el-input[^>]*v-model="form\.coverUrl"/)
  assert.doesNotMatch(tags, /封面URL|tagForm\.coverUrl/)
  assert.doesNotMatch(artists, /coverUrl:\s*form\.coverUrl/)
  assert.doesNotMatch(albums, /coverUrl:\s*form\.coverUrl/)
  assert.doesNotMatch(tracks, /coverUrl:\s*editForm\.coverUrl/)
})
