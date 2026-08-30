<template>
  <div class="users-view">
    <div class="page-header">
      <div class="header-left">
        <p class="page-subtitle">管理系统用户</p>
      </div>
      <el-button type="primary" :icon="Plus" class="invite-button" @click="openInviteDialog">
        邀请用户
      </el-button>
    </div>

    <el-card class="content-card">
      <el-table
        :data="users"
        v-loading="loading"
        empty-text="暂无用户"
        class="custom-table"
      >
        <el-table-column prop="username" label="用户名" min-width="150">
          <template #default="{ row }">
            <div class="user-cell">
              <div class="user-avatar" :class="{ admin: row.role === 'Admin' }">
                {{ row.username?.charAt(0)?.toUpperCase() }}
              </div>
              <span class="user-name">{{ row.username }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="email" label="邮箱" min-width="180">
          <template #default="{ row }">
            <span class="email-text">{{ row.email }}</span>
          </template>
        </el-table-column>
        <el-table-column label="角色" width="120">
          <template #default="{ row }">
            <el-tag :type="row.role === 'Admin' ? 'danger' : 'info'" class="role-tag">
              {{ row.role === 'Admin' ? '管理员' : '用户' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="playlistCount" label="播放列表" width="100" align="center">
          <template #default="{ row }">
            <span class="count-badge">{{ row.playlistCount || 0 }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="favoriteCount" label="收藏" width="80" align="center">
          <template #default="{ row }">
            <span class="count-badge">{{ row.favoriteCount || 0 }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200">
          <template #default="{ row }">
            <div class="action-buttons">
              <el-button 
                link 
                type="primary" 
                @click="toggleRole(row)"
                :disabled="row.role === 'Admin'"
              >
                {{ row.role === 'Admin' ? '管理员' : '设为管理员' }}
              </el-button>
              <el-button 
                link 
                type="danger" 
                @click="deleteUser(row.id)"
                :disabled="row.role === 'Admin'"
              >
                删除
              </el-button>
            </div>
          </template>
        </el-table-column>
      </el-table>

      <AdminPagination
        v-model:current-page="pagination.page"
        :page-size="pagination.pageSize"
        :total="pagination.total"
        @current-change="loadUsers"
      />
    </el-card>

    <el-dialog
      v-model="inviteDialogVisible"
      title="创建邀请账号"
      width="min(560px, calc(100vw - 32px))"
      append-to-body
      destroy-on-close
      @closed="resetInviteForm"
    >
      <div class="invite-brief">
        <div class="invite-brief__icon">
          <UserFilled />
        </div>
        <div>
          <strong>为成员准备一个可立即登录的账号</strong>
          <p>系统暂不发送邮件，请通过安全渠道交付邮箱和临时密码。</p>
        </div>
      </div>

      <el-form
        ref="inviteFormRef"
        :model="inviteForm"
        :rules="inviteRules"
        label-position="top"
        class="invite-form"
        @submit.prevent="createInvitedUser"
      >
        <div class="form-grid">
          <el-form-item label="用户名" prop="username">
            <el-input
              v-model="inviteForm.username"
              maxlength="32"
              autocomplete="off"
              placeholder="例如 family.member"
            />
          </el-form-item>

          <el-form-item label="角色" prop="role">
            <el-radio-group v-model="inviteForm.role" class="role-selector">
              <el-radio-button value="Member">普通成员</el-radio-button>
              <el-radio-button value="Admin">管理员</el-radio-button>
            </el-radio-group>
          </el-form-item>
        </div>

        <el-form-item label="登录邮箱" prop="email">
          <el-input
            v-model="inviteForm.email"
            type="email"
            autocomplete="off"
            placeholder="member@example.com"
          />
        </el-form-item>

        <el-form-item label="临时密码" prop="password">
          <el-input
            v-model="inviteForm.password"
            type="password"
            show-password
            autocomplete="new-password"
            placeholder="至少 6 位，包含大小写、数字和特殊字符"
          >
            <template #append>
              <el-button :icon="Refresh" aria-label="重新生成临时密码" @click="refreshTemporaryPassword" />
              <el-button :icon="CopyDocument" aria-label="复制临时密码" @click="copyTemporaryPassword" />
            </template>
          </el-input>
          <p class="password-hint">创建后无法再次查看此密码，请先复制并安全交付给用户。</p>
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="inviteDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="inviteSubmitting" @click="createInvitedUser">
          创建账号
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { isAxiosError } from 'axios'
import { CopyDocument, Plus, Refresh, UserFilled } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import api from '@/api'
import AdminPagination from '@/components/AdminPagination.vue'
import {
  generateTemporaryPassword,
  normalizeEmail,
  normalizeUsername,
  validateEmail,
  validatePassword,
  validateUsername
} from '@/utils/userCredentials'

interface AdminUser {
  id: string
  username: string
  email: string
  role: 'Admin' | 'Member'
  playlistCount: number
  favoriteCount: number
}

interface InviteForm {
  username: string
  email: string
  password: string
  role: 'Admin' | 'Member'
}

const loading = ref(false)
const users = ref<AdminUser[]>([])
const pagination = reactive({ page: 1, pageSize: 20, total: 0 })
const inviteDialogVisible = ref(false)
const inviteSubmitting = ref(false)
const inviteFormRef = ref<FormInstance>()
const inviteForm = reactive<InviteForm>({
  username: '',
  email: '',
  password: '',
  role: 'Member'
})

const inviteRules: FormRules<InviteForm> = {
  username: [{
    validator: (_rule, value: string, callback) => completeValidation(validateUsername(value), callback),
    trigger: ['blur', 'change']
  }],
  email: [{
    validator: (_rule, value: string, callback) => completeValidation(validateEmail(value), callback),
    trigger: ['blur', 'change']
  }],
  password: [{
    validator: (_rule, value: string, callback) => completeValidation(validatePassword(value), callback),
    trigger: ['blur', 'change']
  }],
  role: [{ required: true, message: '请选择用户角色', trigger: 'change' }]
}

async function loadUsers() {
  loading.value = true
  try {
    const response = await api.get('/api/admin/users', {
      params: { page: pagination.page, pageSize: pagination.pageSize }
    })
    users.value = response.data.users
    pagination.total = response.data.totalCount
  } catch {
    ElMessage.error('加载用户失败')
  } finally {
    loading.value = false
  }
}

async function toggleRole(user: AdminUser) {
  try {
    await ElMessageBox.confirm(`确定将 ${user.username} 设为管理员？`, '确认')
    await api.put(`/api/admin/users/${user.id}/role`, { role: 'Admin' })
    ElMessage.success('更新成功')
    loadUsers()
  } catch (e: any) {
    if (e !== 'cancel') ElMessage.error('更新失败')
  }
}

function openInviteDialog() {
  resetInviteForm()
  inviteForm.password = generateTemporaryPassword()
  inviteDialogVisible.value = true
}

function resetInviteForm() {
  inviteForm.username = ''
  inviteForm.email = ''
  inviteForm.password = ''
  inviteForm.role = 'Member'
  inviteFormRef.value?.clearValidate()
}

function refreshTemporaryPassword() {
  inviteForm.password = generateTemporaryPassword()
  inviteFormRef.value?.validateField('password')
}

async function copyTemporaryPassword() {
  if (!inviteForm.password) return

  try {
    await navigator.clipboard.writeText(inviteForm.password)
    ElMessage.success('临时密码已复制')
  } catch {
    ElMessage.warning('复制失败，请手动选择密码复制')
  }
}

async function createInvitedUser() {
  if (!inviteFormRef.value || inviteSubmitting.value) return

  const isValid = await inviteFormRef.value.validate().catch(() => false)
  if (!isValid) return

  inviteSubmitting.value = true
  try {
    const response = await api.post('/api/admin/users', {
      username: normalizeUsername(inviteForm.username),
      email: normalizeEmail(inviteForm.email),
      password: inviteForm.password,
      role: inviteForm.role
    })

    if (response.data?.code && response.data.code !== 0) {
      throw new Error(response.data.message || '创建用户失败')
    }

    ElMessage.success(`已创建 ${response.data.username} 的账号`)
    inviteDialogVisible.value = false
    pagination.page = 1
    await loadUsers()
  } catch (error: unknown) {
    ElMessage.error(getRequestErrorMessage(error))
  } finally {
    inviteSubmitting.value = false
  }
}

function completeValidation(message: string | null, callback: (error?: Error) => void) {
  callback(message ? new Error(message) : undefined)
}

function getRequestErrorMessage(error: unknown): string {
  if (isAxiosError(error)) {
    return error.response?.data?.message || '创建用户失败'
  }

  return error instanceof Error ? error.message : '创建用户失败'
}

async function deleteUser(id: string) {
  try {
    await ElMessageBox.confirm('确定删除此用户？', '确认')
    await api.delete(`/api/admin/users/${id}`)
    ElMessage.success('删除成功')
    loadUsers()
  } catch (e: any) {
    if (e !== 'cancel') ElMessage.error(e.response?.data?.error || '删除失败')
  }
}

onMounted(loadUsers)
</script>

<style scoped>
.users-view {
  animation: fadeIn 0.5s ease;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

.page-subtitle {
  color: rgba(255, 255, 255, 0.7);
  font-size: 14px;
  margin: 0;
}

.invite-button {
  min-width: 120px;
  height: 42px;
  border-radius: 12px;
}

.invite-brief {
  display: flex;
  gap: 14px;
  align-items: center;
  padding: 16px;
  margin-bottom: 24px;
  color: #27324a;
  background:
    radial-gradient(circle at 88% 10%, rgba(102, 126, 234, 0.2), transparent 42%),
    linear-gradient(135deg, rgba(102, 126, 234, 0.1), rgba(67, 233, 123, 0.08));
  border: 1px solid rgba(102, 126, 234, 0.18);
  border-radius: 14px;
}

.invite-brief__icon {
  display: grid;
  flex: 0 0 44px;
  width: 44px;
  height: 44px;
  place-items: center;
  color: #fff;
  background: var(--primary-gradient);
  border-radius: 13px;
  box-shadow: 0 8px 20px rgba(102, 126, 234, 0.28);
}

.invite-brief__icon svg {
  width: 22px;
  height: 22px;
}

.invite-brief strong {
  display: block;
  margin-bottom: 3px;
  font-size: 15px;
}

.invite-brief p,
.password-hint {
  margin: 0;
  color: #6b7280;
  font-size: 12px;
  line-height: 1.6;
}

.invite-form :deep(.el-form-item__label) {
  color: #35415a;
  font-weight: 600;
}

.form-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 180px;
  gap: 16px;
}

.role-selector {
  display: flex;
  width: 100%;
}

.role-selector :deep(.el-radio-button) {
  flex: 1;
}

.role-selector :deep(.el-radio-button__inner) {
  width: 100%;
}

.password-hint {
  width: 100%;
  margin-top: 7px;
}

@media (max-width: 640px) {
  .page-header {
    align-items: stretch;
    flex-direction: column;
    gap: 12px;
  }

  .form-grid {
    grid-template-columns: 1fr;
    gap: 0;
  }
}

.content-card {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: var(--radius-lg);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
}

.content-card :deep(.el-card__body) {
  padding: 0;
}

/* Table dark mode styling */
.content-card :deep(.el-table) {
  background: transparent;
}

.content-card :deep(.el-table tr) {
  background: transparent;
}

.content-card :deep(.el-table th.el-table__cell) {
  background: rgba(255, 255, 255, 0.05) !important;
  color: rgba(255, 255, 255, 0.9) !important;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.content-card :deep(.el-table td.el-table__cell) {
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  color: rgba(255, 255, 255, 0.85);
}

.content-card :deep(.el-table__body tr:hover > td) {
  background: rgba(255, 255, 255, 0.08) !important;
}

.user-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}

.user-avatar {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: var(--gradient-users);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 16px;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
}

.user-avatar.admin {
  background: linear-gradient(135deg, #f5576c 0%, #f093fb 100%);
  box-shadow: 0 2px 8px rgba(245, 87, 108, 0.3);
}

.user-name {
  font-weight: 600;
  color: #ffffff;
}

.email-text {
  color: rgba(255, 255, 255, 0.65);
}

.role-tag {
  font-weight: 500;
}

.count-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  height: 24px;
  padding: 0 8px;
  background: rgba(102, 126, 234, 0.1);
  color: var(--primary-color);
  border-radius: 12px;
  font-weight: 600;
  font-size: 13px;
}

.action-buttons {
  display: flex;
  gap: 8px;
}

</style>
