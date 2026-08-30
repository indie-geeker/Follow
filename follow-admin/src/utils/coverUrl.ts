const ALLOWED_COVER_PREFIXES = new Set(['covers', 'artists', 'albums'])
const ALLOWED_COVER_EXTENSION = /\.(?:jpe?g|png|webp|gif)$/i

export function normalizeCoverObjectKey(value: unknown): string | null {
  if (typeof value !== 'string') return null

  const objectKey = value.trim()
  if (!objectKey || objectKey.startsWith('/') || objectKey.includes('\\')) return null

  const segments = objectKey.split('/')
  if (
    segments.length < 2
    || !ALLOWED_COVER_PREFIXES.has(segments[0] ?? '')
    || segments.some((segment) => !segment || segment === '.' || segment === '..')
    || !ALLOWED_COVER_EXTENSION.test(segments[segments.length - 1] ?? '')
  ) {
    return null
  }

  return objectKey
}

export function toCoverProxyUrl(value: unknown): string {
  const objectKey = normalizeCoverObjectKey(value)
  if (!objectKey) return ''

  const encodedPath = objectKey
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/')
  return `/api/tracks/cover/${encodedPath}`
}
