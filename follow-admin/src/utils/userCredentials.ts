const usernamePattern = /^[\p{L}\p{N}][\p{L}\p{N}._-]{1,30}[\p{L}\p{N}]$/u
const emailPattern = /^[^\s@]+@[^\s@]+$/u

export function normalizeUsername(value: string): string {
  return value.normalize('NFKC').trim().toLowerCase()
}

export function normalizeEmail(value: string): string {
  return value.normalize('NFKC').trim().toLowerCase()
}

export function validateUsername(value: string): string | null {
  const username = normalizeUsername(value)

  if (username.length < 3 || username.length > 32) {
    return '用户名必须为 3-32 个字符'
  }

  if (!usernamePattern.test(username)) {
    return '只能包含字母、数字、点、下划线或连字符，且必须以字母或数字开头和结尾'
  }

  return null
}

export function validateEmail(value: string): string | null {
  return emailPattern.test(normalizeEmail(value)) ? null : '请输入有效的邮箱地址'
}

export function validatePassword(value: string): string | null {
  if (value.length < 6 || value.length > 128) {
    return '密码长度必须为 6-128 个字符'
  }

  if (/\s/u.test(value)) {
    return '密码不能包含空白字符'
  }

  if (!/\p{Lu}/u.test(value) ||
      !/\p{Ll}/u.test(value) ||
      !/\p{N}/u.test(value) ||
      !/[^\p{L}\p{N}]/u.test(value)) {
    return '密码必须同时包含大写字母、小写字母、数字和特殊字符'
  }

  return null
}

export function generateTemporaryPassword(length = 20): string {
  if (length < 6 || length > 128) {
    throw new RangeError('临时密码长度必须为 6-128 个字符')
  }

  const uppercase = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
  const lowercase = 'abcdefghijkmnopqrstuvwxyz'
  const digits = '23456789'
  const special = '!@#$%^&*_-+='
  const allCharacters = uppercase + lowercase + digits + special
  const characters = [
    randomCharacter(uppercase),
    randomCharacter(lowercase),
    randomCharacter(digits),
    randomCharacter(special)
  ]

  while (characters.length < length) {
    characters.push(randomCharacter(allCharacters))
  }

  for (let index = characters.length - 1; index > 0; index -= 1) {
    const swapIndex = randomIndex(index + 1)
    ;[characters[index], characters[swapIndex]] = [characters[swapIndex]!, characters[index]!]
  }

  return characters.join('')
}

function randomCharacter(characters: string): string {
  return characters[randomIndex(characters.length)]!
}

function randomIndex(maximum: number): number {
  const randomValue = new Uint32Array(1)
  globalThis.crypto.getRandomValues(randomValue)
  return randomValue[0]! % maximum
}
