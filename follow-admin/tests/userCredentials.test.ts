import assert from 'node:assert/strict'
import test from 'node:test'
import {
  generateTemporaryPassword,
  normalizeEmail,
  normalizeUsername,
  validateEmail,
  validatePassword,
  validateUsername
} from '../src/utils/userCredentials.ts'

test('normalizes usernames and email addresses like the API', () => {
  assert.equal(normalizeUsername('  Ａdmin.User  '), 'admin.user')
  assert.equal(normalizeEmail('  Admin@Example.COM '), 'admin@example.com')
})

test('validates the shared username contract', () => {
  assert.equal(validateUsername('member.user'), null)
  assert.match(validateUsername('ab') ?? '', /3-32/)
  assert.match(validateUsername('_member') ?? '', /字母或数字/)
  assert.match(validateUsername('member name') ?? '', /只能包含/)
})

test('validates the shared email and password contract', () => {
  assert.equal(validateEmail('member@example.com'), null)
  assert.ok(validateEmail('not-an-email'))
  assert.equal(validatePassword('Aa1!bc'), null)
  assert.match(validatePassword('Aa1!b') ?? '', /6-128/)
  assert.match(validatePassword('NoSpecialPassword2026') ?? '', /特殊字符/)
  assert.match(validatePassword('Aa1! bc') ?? '', /空白字符/)
})

test('generates a strong temporary password', () => {
  const password = generateTemporaryPassword(6)

  assert.equal(password.length, 6)
  assert.equal(validatePassword(password), null)
  assert.throws(() => generateTemporaryPassword(5), /6-128/)
})
