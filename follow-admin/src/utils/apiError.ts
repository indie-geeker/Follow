function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null
    ? value as Record<string, unknown>
    : null
}

export function getApiErrorMessage(error: unknown, fallback: string): string {
  const response = asRecord(asRecord(error)?.response)
  const data = asRecord(response?.data)

  for (const candidate of [data?.message, data?.error]) {
    if (typeof candidate === 'string' && candidate.trim()) {
      return candidate
    }
  }

  if (error instanceof Error && error.message.trim()) {
    return error.message
  }

  return fallback
}
