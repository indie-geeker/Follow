export const REMEMBERED_ACCOUNT_KEY = 'rememberedAccount'
export const LEGACY_CREDENTIALS_KEY = 'savedCredentials'

interface AccountStorage {
  getItem(key: string): string | null
  setItem(key: string, value: string): void
  removeItem(key: string): void
}

function parseIdentifier(value: string | null): string {
  if (!value) return ''

  try {
    const parsed = JSON.parse(value) as { identifier?: unknown; email?: unknown }
    if (typeof parsed.identifier === 'string') return parsed.identifier.trim()
    return typeof parsed.email === 'string' ? parsed.email.trim() : ''
  } catch {
    return ''
  }
}

export function loadRememberedIdentifier(storage: AccountStorage): string {
  const savedIdentifier = parseIdentifier(storage.getItem(REMEMBERED_ACCOUNT_KEY))
  const legacyIdentifier = parseIdentifier(storage.getItem(LEGACY_CREDENTIALS_KEY))
  const identifier = savedIdentifier || legacyIdentifier

  storage.removeItem(LEGACY_CREDENTIALS_KEY)

  if (identifier) {
    storage.setItem(REMEMBERED_ACCOUNT_KEY, JSON.stringify({ identifier }))
  } else {
    storage.removeItem(REMEMBERED_ACCOUNT_KEY)
  }

  return identifier
}

export function persistRememberedIdentifier(
  storage: AccountStorage,
  identifier: string,
  remember: boolean
): void {
  const normalizedIdentifier = identifier.trim()

  storage.removeItem(LEGACY_CREDENTIALS_KEY)

  if (remember && normalizedIdentifier) {
    storage.setItem(REMEMBERED_ACCOUNT_KEY, JSON.stringify({
      identifier: normalizedIdentifier
    }))
    return
  }

  storage.removeItem(REMEMBERED_ACCOUNT_KEY)
}
