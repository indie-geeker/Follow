import assert from 'node:assert/strict'
import test from 'node:test'

import { getApiErrorMessage } from '../src/utils/apiError.ts'

test('uses the API envelope message for HTTP authentication errors', () => {
  const error = {
    response: {
      status: 401,
      data: { code: 401, message: '邮箱或密码错误' }
    }
  }

  assert.equal(getApiErrorMessage(error, '登录失败'), '邮箱或密码错误')
})

test('falls back through legacy errors and ordinary Error instances', () => {
  assert.equal(
    getApiErrorMessage({ response: { data: { error: '旧版错误' } } }, '失败'),
    '旧版错误'
  )
  assert.equal(getApiErrorMessage(new Error('网络不可用'), '失败'), '网络不可用')
  assert.equal(getApiErrorMessage(null, '登录失败'), '登录失败')
})
