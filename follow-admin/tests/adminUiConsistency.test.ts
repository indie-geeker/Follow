import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

function readSource(relativePath: string): string {
  return readFileSync(fileURLToPath(new URL(`../src/${relativePath}`, import.meta.url)), 'utf8')
}

function readProjectFile(relativePath: string): string {
  return readFileSync(fileURLToPath(new URL(`../${relativePath}`, import.meta.url)), 'utf8')
}

test('user and track lists share the same admin pagination component', () => {
  const componentUrl = new URL('../src/components/AdminPagination.vue', import.meta.url)
  assert.ok(existsSync(componentUrl), 'AdminPagination.vue should centralize the list pagination UI')

  for (const viewPath of ['views/users/UsersView.vue', 'views/music/TracksView.vue']) {
    const source = readSource(viewPath)
    assert.match(source, /import AdminPagination from ['"]@\/components\/AdminPagination\.vue['"]/)
    assert.match(source, /<AdminPagination\b/)
    assert.doesNotMatch(source, /<el-pagination\b/)
  }

  const pagination = readSource('components/AdminPagination.vue')
  assert.match(pagination, /\.admin-pagination :deep\(\.btn-prev\)/)
  assert.match(pagination, /\.admin-pagination :deep\(\.el-pager li\.is-active\)/)
  assert.match(pagination, /\.admin-pagination :deep\(\.el-pagination__total\)/)
})

test('sidebar menu keeps a stable transparent border during route changes', () => {
  const source = readSource('layouts/AdminLayout.vue')
  const baseRule = source.match(/\.sidebar-menu :deep\(\.el-menu-item\) \{([\s\S]*?)\n\}/)?.[1] ?? ''
  const activeRule = source.match(/\.sidebar-menu :deep\(\.el-menu-item\.is-active\) \{([\s\S]*?)\n\}/)?.[1] ?? ''

  assert.doesNotMatch(baseRule, /transition:\s*all\b/)
  assert.match(baseRule, /border:\s*1px solid transparent/)
  assert.doesNotMatch(activeRule, /border:\s*none/)
  assert.match(activeRule, /border-color:\s*transparent/)
  assert.match(source, /\.sidebar-menu :deep\(\.el-menu-item:focus-visible\)/)
})

test('album list renders missing years without an empty tag and preserves null on edit', () => {
  const source = readSource('views/music/AlbumsView.vue')

  assert.match(source, /formatOptionalYear\(row\.year\)/)
  assert.doesNotMatch(source, /<el-tag[^>]*>\s*\{\{\s*row\.year\s*\}\}\s*<\/el-tag>/)
  assert.match(source, /album\?\.year\s*\?\?\s*undefined/)
  assert.match(source, /normalizeOptionalYear\(form\.year\)/)
})

test('admin shell has responsive navigation and deterministic animations', () => {
  const layout = readSource('layouts/AdminLayout.vue')
  const login = readSource('views/auth/LoginView.vue')

  assert.match(layout, /aria-label="打开导航菜单"/)
  assert.match(layout, /<Expand \/>/)
  assert.match(layout, /is-mobile-open/)
  assert.match(layout, /@media \(max-width: 1023px\)/)
  assert.match(layout, /@media \(max-width: 767px\)/)
  assert.doesNotMatch(layout, /document\.createElement\(['"]style['"]\)/)
  assert.doesNotMatch(login, /document\.createElement\(['"]style['"]\)/)
})

test('shared admin styles protect motion preferences and action target sizes', () => {
  const source = readSource('styles/admin-components.css')

  assert.match(source, /@media \(prefers-reduced-motion: reduce\)/)
  assert.match(source, /min-height:\s*44px/)
  assert.match(source, /min-width:\s*44px/)
})

test('track play control has an accessible name', () => {
  const source = readSource('views/music/TracksView.vue')
  assert.match(source, /:aria-label="`播放：\$\{row\.title\}`"/)
})

test('Element Plus is registered through the scoped plugin instead of the full bundle', () => {
  const main = readSource('main.ts')
  const plugin = readSource('plugins/elementPlus.ts')

  assert.doesNotMatch(main, /import ElementPlus from ['"]element-plus['"]/)
  assert.doesNotMatch(main, /element-plus\/dist\/index\.css/)
  assert.match(main, /installElementPlus\(app\)/)
  assert.match(plugin, /ElTable/)
  assert.match(plugin, /ElLoading/)
  assert.match(plugin, /\bElRadio\b/)
})

test('large framework dependencies are split into cacheable vendor chunks', () => {
  const config = readProjectFile('vite.config.ts')

  assert.match(config, /manualChunks/)
  assert.match(config, /element-plus/)
  assert.match(config, /vue-vendor/)
})
