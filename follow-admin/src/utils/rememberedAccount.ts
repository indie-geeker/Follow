export const REMEMBERED_ACCOUNT_KEY = 'rememberedAccount'
export const LEGACY_CREDENTIALS_KEY = 'savedCredentials'

interface AccountStorage {
  getItem(key: string): string | null
  setItem(key: string, value: string): void
  removeItem(key: string): void
}

function parseEmail(value: string | null): string {
  if (!value) return ''

  try {
    const parsed = JSON.parse(value) as { email?: unknown }
    return typeof parsed.email === 'string' ? parsed.email.trim() : ''
  } catch {
    return ''
  }
}

export function loadRememberedEmail(storage: AccountStorage): string {
  const savedEmail = parseEmail(storage.getItem(REMEMBERED_ACCOUNT_KEY))
  const legacyEmail = parseEmail(storage.getItem(LEGACY_CREDENTIALS_KEY))
  const email = savedEmail || legacyEmail

  storage.removeItem(LEGACY_CREDENTIALS_KEY)

  if (email) {
    storage.setItem(REMEMBERED_ACCOUNT_KEY, JSON.stringify({ email }))
  } else {
    storage.removeItem(REMEMBERED_ACCOUNT_KEY)
  }

  return email
}

export function persistRememberedEmail(
  storage: AccountStorage,
  email: string,
  remember: boolean
): void {
  const normalizedEmail = email.trim()

  storage.removeItem(LEGACY_CREDENTIALS_KEY)

  if (remember && normalizedEmail) {
    storage.setItem(REMEMBERED_ACCOUNT_KEY, JSON.stringify({ email: normalizedEmail }))
    return
  }

  storage.removeItem(REMEMBERED_ACCOUNT_KEY)
}
