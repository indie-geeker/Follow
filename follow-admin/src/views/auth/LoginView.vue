<template>
  <div class="login-container">
    <!-- Animated background circles -->
    <div class="bg-circles">
      <div
        v-for="index in 4"
        :key="index"
        class="circle"
        :class="`circle-${index}`"
      ></div>
    </div>

    <!-- Login card -->
    <div class="login-card">
      <!-- Music icon header -->
      <div class="logo-container">
        <div class="logo-icon">
          <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M9 18V5l12-2v13" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            <circle cx="6" cy="18" r="3" stroke="currentColor" stroke-width="2"/>
            <circle cx="18" cy="16" r="3" stroke="currentColor" stroke-width="2"/>
          </svg>
        </div>
      </div>

      <h1 class="title">Follow Music</h1>
      <p class="subtitle">音乐管理后台</p>
      
      <el-form
        ref="formRef"
        :model="form"
        :rules="rules"
        class="login-form"
        @submit.prevent="handleLogin"
      >
        <el-form-item prop="identifier" ref="identifierFormItem" :class="{ shake: identifierShake }">
          <el-input
            v-model="form.identifier"
            placeholder="请输入用户名或邮箱"
            size="large"
            :prefix-icon="User"
            class="custom-input"
            @blur="validateField('identifier')"
            @keyup.enter="handleLogin"
          />
        </el-form-item>

        <el-form-item prop="password" ref="passwordFormItem" :class="{ shake: passwordShake }">
          <el-input
            v-model="form.password"
            type="password"
            placeholder="请输入密码"
            size="large"
            :prefix-icon="Lock"
            show-password
            class="custom-input"
            @blur="validateField('password')"
            @keyup.enter="handleLogin"
          />
        </el-form-item>
        
        <el-form-item class="remember-item">
          <el-checkbox v-model="form.rememberMe">记住账号</el-checkbox>
        </el-form-item>
        
        <el-form-item class="submit-item">
          <el-button
            type="primary"
            native-type="button"
            size="large"
            :loading="loading"
            class="login-btn"
            @click="handleLogin"
          >
            <span v-if="!loading">登 录</span>
          </el-button>
        </el-form-item>
      </el-form>

      <div class="footer-text">
        <span>© 2026 Follow Music. All rights reserved.</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, type FormInstance } from 'element-plus'
import { User, Lock } from '@element-plus/icons-vue'
import { useAuthStore } from '@/stores/auth'
import { getApiErrorMessage } from '@/utils/apiError'
import {
  loadRememberedIdentifier,
  persistRememberedIdentifier
} from '@/utils/rememberedAccount'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const formRef = ref<FormInstance>()
const loading = ref(false)

// Shake animation state
const identifierShake = ref(false)
const passwordShake = ref(false)

const rememberedIdentifier = loadRememberedIdentifier(localStorage)

const form = reactive({
  identifier: rememberedIdentifier,
  password: '',
  rememberMe: Boolean(rememberedIdentifier)
})

watch(() => form.rememberMe, (newValue) => {
  if (!newValue) {
    persistRememberedIdentifier(localStorage, form.identifier, false)
  }
})

const rules = {
  identifier: [
    { required: true, message: '请输入用户名或邮箱', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码至少6位', trigger: 'blur' }
  ]
}

// Validate single field
function validateField(field: 'identifier' | 'password') {
  if (!formRef.value) return
  formRef.value.validateField(field, (_valid) => {
    // Validation callback - no action needed
  })
}

// Trigger shake animation
function triggerShake(field: 'identifier' | 'password') {
  if (field === 'identifier') {
    identifierShake.value = true
    setTimeout(() => { identifierShake.value = false }, 500)
  } else if (field === 'password') {
    passwordShake.value = true
    setTimeout(() => { passwordShake.value = false }, 500)
  }
}

const handleLogin = async () => {
  if (!formRef.value) return

  try {
    // Validate form
    const valid = await formRef.value.validate()
    if (!valid) return

    loading.value = true

    await authStore.login(form.identifier.trim(), form.password)

    persistRememberedIdentifier(localStorage, form.identifier, form.rememberMe)

    ElMessage.success('登录成功')
    const redirect = typeof route.query.redirect === 'string'
      && route.query.redirect.startsWith('/')
      && !route.query.redirect.startsWith('//')
      ? route.query.redirect
      : '/'
    await router.push(redirect)
  } catch (error: unknown) {
    ElMessage.error(getApiErrorMessage(error, '登录失败'))
    triggerShake('identifier')
    triggerShake('password')
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
/* Container with animated gradient background */
.login-container {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(-45deg, #1a1a2e, #16213e, #0f3460, #533483);
  background-size: 400% 400%;
  animation: gradientShift 15s ease infinite;
  position: relative;
  overflow: hidden;
}

@keyframes gradientShift {
  0% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
  100% { background-position: 0% 50%; }
}

/* Floating background circles */
.bg-circles {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
  z-index: 0;
}

.circle {
  position: absolute;
  border-radius: 50%;
  background: linear-gradient(135deg, rgba(102, 126, 234, 0.3), rgba(118, 75, 162, 0.3));
  filter: blur(40px);
  will-change: transform;
  animation: circleDrift 30s ease-in-out infinite;
}

@keyframes circleDrift {
  0%, 100% { transform: translate3d(0, 0, 0) rotate(0deg) scale(1); }
  33% { transform: translate3d(18vw, -12vh, 0) rotate(120deg) scale(1.08); }
  66% { transform: translate3d(-12vw, 16vh, 0) rotate(240deg) scale(0.92); }
}

.circle-1 {
  width: 400px;
  height: 400px;
  top: -100px;
  left: -100px;
}

.circle-2 {
  width: 300px;
  height: 300px;
  top: 50%;
  right: -50px;
  background: linear-gradient(135deg, rgba(236, 72, 153, 0.25), rgba(239, 68, 68, 0.25));
  animation-duration: 34s;
  animation-delay: -8s;
}

.circle-3 {
  width: 250px;
  height: 250px;
  bottom: -50px;
  left: 30%;
  background: linear-gradient(135deg, rgba(34, 211, 238, 0.25), rgba(59, 130, 246, 0.25));
  animation-duration: 28s;
  animation-delay: -16s;
}

.circle-4 {
  width: 350px;
  height: 350px;
  top: 40%;
  left: 10%;
  background: linear-gradient(135deg, rgba(168, 85, 247, 0.2), rgba(236, 72, 153, 0.2));
  animation-duration: 38s;
  animation-delay: -24s;
}

/* Glassmorphism login card */
.login-card {
  width: 420px;
  padding: 48px 40px;
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border-radius: 24px;
  border: 1px solid rgba(255, 255, 255, 0.18);
  box-shadow:
    0 8px 32px rgba(0, 0, 0, 0.3),
    inset 0 1px 0 rgba(255, 255, 255, 0.15);
  z-index: 1;
  animation: cardAppear 0.6s ease-out;
  position: relative;
  overflow: hidden;
}

/* Light and shadow gradient effect from top-left to bottom-right */
.login-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(
    135deg,
    rgba(255, 255, 255, 0.35) 0%,
    rgba(255, 255, 255, 0.15) 20%,
    rgba(255, 255, 255, 0.05) 40%,
    rgba(0, 0, 0, 0) 60%,
    rgba(0, 0, 0, 0.15) 80%,
    rgba(0, 0, 0, 0.25) 100%
  );
  border-radius: 24px;
  pointer-events: none;
  z-index: -1;
}

/* Additional highlight on top edge */
.login-card::after {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 1px;
  background: linear-gradient(
    90deg,
    rgba(255, 255, 255, 0) 0%,
    rgba(255, 255, 255, 0.6) 50%,
    rgba(255, 255, 255, 0) 100%
  );
  border-radius: 24px 24px 0 0;
  z-index: 1;
}

@keyframes cardAppear {
  from {
    opacity: 0;
    transform: translateY(30px) scale(0.95);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

/* Logo section */
.logo-container {
  display: flex;
  justify-content: center;
  margin-bottom: 20px;
}

.logo-icon {
  width: 72px;
  height: 72px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8px 24px rgba(102, 126, 234, 0.4);
  animation: logoBreathe 3s ease-in-out infinite;
}

.logo-icon svg {
  width: 40px;
  height: 40px;
  color: white;
}

/* Logo breathing and bouncing animation */
@keyframes logoBreathe {
  0%, 100% {
    transform: scale(1) translateY(0) rotate(0deg);
    box-shadow: 0 8px 24px rgba(102, 126, 234, 0.4);
  }
  25% {
    transform: scale(1.08) translateY(0) rotate(0deg);
    box-shadow: 0 10px 30px rgba(102, 126, 234, 0.5);
  }
  50% {
    transform: scale(1) translateY(0) rotate(0deg);
    box-shadow: 0 8px 24px rgba(102, 126, 234, 0.4);
  }
  58% {
    transform: scale(1) translateY(-8px) rotate(-3deg);
    box-shadow: 0 12px 28px rgba(102, 126, 234, 0.45);
  }
  66% {
    transform: scale(1) translateY(0) rotate(3deg);
    box-shadow: 0 8px 24px rgba(102, 126, 234, 0.4);
  }
  74% {
    transform: scale(1) translateY(-4px) rotate(-1deg);
    box-shadow: 0 10px 26px rgba(102, 126, 234, 0.42);
  }
  82% {
    transform: scale(1) translateY(0) rotate(0deg);
    box-shadow: 0 8px 24px rgba(102, 126, 234, 0.4);
  }
}

/* Typography */
.title {
  text-align: center;
  margin-bottom: 8px;
  font-size: 28px;
  font-weight: 700;
  color: #ffffff;
  letter-spacing: 1px;
  text-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
}

.subtitle {
  text-align: center;
  color: rgba(255, 255, 255, 0.7);
  margin-bottom: 36px;
  font-size: 15px;
  letter-spacing: 2px;
}

/* Form styles */
.login-form {
  margin-top: 24px;
}

.login-form :deep(.el-form-item) {
  margin-bottom: 24px;
}

.login-form :deep(.el-input__wrapper) {
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 12px;
  box-shadow: none;
  transition: all 0.3s ease;
  padding: 4px 16px;
}

.login-form :deep(.el-input__wrapper:hover) {
  background: rgba(255, 255, 255, 0.12);
  border-color: rgba(255, 255, 255, 0.2);
}

.login-form :deep(.el-input__wrapper.is-focus) {
  background: rgba(255, 255, 255, 0.15);
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.25);
}

.login-form :deep(.el-input__inner) {
  color: #ffffff;
  font-size: 15px;
}

.login-form :deep(.el-input__inner::placeholder) {
  color: rgba(255, 255, 255, 0.5);
}

.login-form :deep(.el-input__prefix) {
  color: rgba(255, 255, 255, 0.6);
}

.login-form :deep(.el-input__suffix) {
  color: rgba(255, 255, 255, 0.6);
}

/* Remember checkbox */
.remember-item {
  margin-bottom: 28px !important;
}

.remember-item :deep(.el-checkbox__label) {
  color: rgba(255, 255, 255, 0.7);
  font-size: 14px;
}

.remember-item :deep(.el-checkbox__inner) {
  background: rgba(255, 255, 255, 0.1);
  border-color: rgba(255, 255, 255, 0.3);
}

.remember-item :deep(.el-checkbox__input.is-checked .el-checkbox__inner) {
  background-color: #667eea;
  border-color: #667eea;
}

/* Login button */
.submit-item {
  margin-bottom: 20px !important;
}

.login-btn {
  width: 100%;
  height: 48px;
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 4px;
  border: none;
  border-radius: 12px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
  transition: all 0.3s ease;
}

.login-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 30px rgba(102, 126, 234, 0.5);
  background: linear-gradient(135deg, #7b8ff0 0%, #8b5fbf 100%);
}

.login-btn:active {
  transform: translateY(0);
}

/* Footer text */
.footer-text {
  text-align: center;
  margin-top: 24px;
  color: rgba(255, 255, 255, 0.4);
  font-size: 12px;
}

/* Form error styles */
.login-form :deep(.el-form-item__error) {
  color: #f87171;
  font-size: 12px;
  padding-top: 4px;
}

/* Shake animation for validation errors */
@keyframes shake {
  0%, 100% { transform: translateX(0); }
  10%, 30%, 50%, 70%, 90% { transform: translateX(-8px); }
  20%, 40%, 60%, 80% { transform: translateX(8px); }
}

.shake {
  animation: shake 0.5s ease-in-out;
}

/* Error state for input */
.login-form :deep(.el-form-item.is-error .el-input__wrapper) {
  border-color: #f87171 !important;
  background: rgba(248, 113, 113, 0.1) !important;
}

/* Responsive design */
@media (max-width: 480px) {
  .login-card {
    width: 90%;
    padding: 36px 24px;
    margin: 20px;
  }
  
  .title {
    font-size: 24px;
  }
  
  .logo-icon {
    width: 60px;
    height: 60px;
  }
  
  .logo-icon svg {
    width: 32px;
    height: 32px;
  }
}
</style>
