export function formatOptionalYear(year: number | null | undefined): string {
  return typeof year === 'number' && Number.isFinite(year) && year > 0
    ? String(year)
    : '—'
}

export function normalizeOptionalYear(year: number | null | undefined): number | null {
  return typeof year === 'number' && Number.isFinite(year) && year > 0
    ? year
    : null
}
