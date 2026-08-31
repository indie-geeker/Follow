<template>
  <div class="create-import-page">
    <button class="back-link" type="button" @click="router.push({ name: 'MusicImports' })">
      <el-icon><ArrowLeft /></el-icon>
      返回任务列表
    </button>

    <div class="create-grid">
      <el-card class="form-panel">
        <div class="panel-heading">
          <span class="step-index">01</span>
          <div>
            <span class="eyebrow">SOURCE SELECTION</span>
            <h2>选择服务器目录</h2>
            <p>填写只读挂载根目录下的相对路径，由服务器递归扫描音频文件。</p>
          </div>
        </div>

        <div v-if="capabilityMessage" class="capability-note" :class="capabilityNoteClass">
          <span class="capability-note__dot" aria-hidden="true"></span>
          <span>{{ capabilityMessage }}</span>
        </div>

        <el-form label-position="top" @submit.prevent="createBatch">
          <el-form-item label="相对目录">
            <el-input
              v-model="form.relativeDirectory"
              :disabled="!sourceReady || submitting"
              placeholder="留空扫描整个挂载目录，或填写：无损/古典"
              autocomplete="off"
              @keyup.enter="createBatch"
            />
            <p class="field-hint">
              留空表示整个服务器挂载目录；也可填写其下的相对目录。不要填写本机路径或绝对路径。
            </p>
          </el-form-item>

          <el-form-item>
            <el-checkbox
              v-model="form.autoStart"
              :disabled="!sourceReady || submitting"
            >
              扫描完成后自动开始相似分析
            </el-checkbox>
          </el-form-item>

          <div class="form-actions">
            <el-button :disabled="submitting" @click="router.push({ name: 'MusicImports' })">
              取消
            </el-button>
            <el-button
              type="primary"
              :loading="submitting"
              :disabled="!canSubmit"
              @click="createBatch"
            >
              创建并扫描
            </el-button>
          </div>
        </el-form>
      </el-card>

      <aside class="safety-panel">
        <span class="eyebrow">SAFETY CONTRACT</span>
        <h3>这不是浏览器文件上传</h3>
        <ol class="safety-steps">
          <li>
            <span>1</span>
            <div>
              <strong>服务器挂载</strong>
              <p>运维人员先将指定音乐文件夹挂载到 Follow Server。</p>
            </div>
          </li>
          <li>
            <span>2</span>
            <div>
              <strong>只读扫描</strong>
              <p>服务端递归读取目录，不重命名、移动或删除任何源文件。</p>
            </div>
          </li>
          <li>
            <span>3</span>
            <div>
              <strong>可恢复任务</strong>
              <p>每个文件单独记录结果，可暂停、恢复并重试失败项。</p>
            </div>
          </li>
        </ol>
        <div class="format-note">
          <span>支持格式</span>
          <strong>{{ supportedFormats }}</strong>
        </div>
      </aside>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { ArrowLeft } from '@element-plus/icons-vue'
import musicImports from '@/api/musicImports'
import type { MusicImportCapabilities } from '@/types/musicImport'
import { getApiErrorMessage } from '@/utils/apiError'

const router = useRouter()
const capabilities = ref<MusicImportCapabilities | null>(null)
const loadingCapabilities = ref(true)
const submitting = ref(false)
const clientRequestId = crypto.randomUUID()
const form = reactive({
  relativeDirectory: '',
  autoStart: false
})

const sourceReady = computed(() => Boolean(
  capabilities.value?.enabled && capabilities.value.sourceAvailable
))

const canSubmit = computed(() => (
  sourceReady.value &&
  !submitting.value
))

const capabilityMessage = computed(() => {
  if (loadingCapabilities.value) return '正在检查服务器挂载状态…'
  if (!capabilities.value?.enabled) return '音乐库初始化功能未启用，请联系运维人员。'
  if (!capabilities.value.sourceAvailable) return '服务器源目录尚未挂载，暂时不能创建任务。'
  return capabilities.value.sourceAlias
    ? `服务器只读源已就绪：${capabilities.value.sourceAlias}`
    : '服务器只读源目录已就绪。'
})

const capabilityNoteClass = computed(() => ({
  'capability-note--ready': sourceReady.value
}))

const supportedFormats = 'MP3 · FLAC · WAV · AAC · OGG · M4A'

async function loadCapabilities() {
  loadingCapabilities.value = true
  try {
    capabilities.value = await musicImports.getCapabilities()
  } catch (error) {
    ElMessage.error(getApiErrorMessage(error, '无法读取服务器导入配置'))
  } finally {
    loadingCapabilities.value = false
  }
}

async function createBatch() {
  if (!canSubmit.value) return

  submitting.value = true
  try {
    const batch = await musicImports.createBatch({
      clientRequestId,
      relativeDirectory: form.relativeDirectory.trim(),
      autoStart: form.autoStart
    })
    ElMessage.success('导入任务已创建，服务器正在扫描目录')
    await router.push({ name: 'MusicImportDetail', params: { jobId: batch.id } })
  } catch (error) {
    ElMessage.error(getApiErrorMessage(error, '任务创建失败，请检查目录后重试'))
  } finally {
    submitting.value = false
  }
}

onMounted(() => {
  void loadCapabilities()
})
</script>

<style scoped>
.create-import-page {
  display: grid;
  gap: 18px;
  max-width: 1120px;
  margin: 0 auto;
}

.back-link {
  display: inline-flex;
  align-items: center;
  justify-self: start;
  gap: 7px;
  min-height: 40px;
  padding: 0;
  color: rgba(255, 255, 255, 0.72);
  background: none;
  border: 0;
  cursor: pointer;
}

.back-link:hover {
  color: #fff;
}

.create-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.55fr) minmax(280px, 0.85fr);
  gap: 20px;
  align-items: start;
}

.form-panel {
  background: rgba(15, 23, 42, 0.58);
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: var(--radius-lg);
  box-shadow: 0 18px 48px rgba(3, 7, 18, 0.3);
  backdrop-filter: blur(20px);
}

.form-panel :deep(.el-card__body) {
  padding: 28px;
}

.panel-heading {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 16px;
  margin-bottom: 24px;
}

.step-index {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  color: #c7d2fe;
  font: 700 13px/1 'SF Mono', ui-monospace, monospace;
  background: rgba(99, 102, 241, 0.18);
  border: 1px solid rgba(129, 140, 248, 0.35);
  border-radius: 10px;
}

.eyebrow {
  color: #9ca3ff;
  font: 700 11px/1.2 'SF Mono', ui-monospace, monospace;
  letter-spacing: 0.12em;
}

.panel-heading h2,
.safety-panel h3 {
  margin: 5px 0 7px;
  color: #fff;
}

.panel-heading p,
.safety-panel p {
  margin: 0;
  color: rgba(255, 255, 255, 0.6);
  font-size: 13px;
  line-height: 1.6;
}

.capability-note {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 22px;
  padding: 12px 14px;
  color: #fecaca;
  background: rgba(127, 29, 29, 0.3);
  border: 1px solid rgba(248, 113, 113, 0.3);
  border-radius: 10px;
  font-size: 13px;
}

.capability-note--warning {
  color: #fde68a;
  background: rgba(120, 53, 15, 0.3);
  border-color: rgba(251, 191, 36, 0.3);
}

.capability-note--ready {
  color: #a7f3d0;
  background: rgba(6, 78, 59, 0.3);
  border-color: rgba(52, 211, 153, 0.3);
}

.capability-note__dot {
  flex: 0 0 auto;
  width: 8px;
  height: 8px;
  background: currentColor;
  border-radius: 50%;
}

.form-panel :deep(.el-form-item__label) {
  color: rgba(255, 255, 255, 0.82);
  font-weight: 600;
}

.field-hint {
  margin: 8px 0 0;
  color: rgba(255, 255, 255, 0.48);
  font-size: 12px;
  line-height: 1.5;
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  padding-top: 8px;
}

.safety-panel {
  padding: 24px;
  color: #fff;
  background:
    linear-gradient(160deg, rgba(67, 56, 202, 0.22), transparent 58%),
    rgba(15, 23, 42, 0.54);
  border: 1px solid rgba(129, 140, 248, 0.22);
  border-radius: var(--radius-lg);
  box-shadow: 0 18px 48px rgba(3, 7, 18, 0.24);
  backdrop-filter: blur(20px);
}

.safety-steps {
  display: grid;
  gap: 18px;
  margin: 24px 0;
  padding: 0;
  list-style: none;
}

.safety-steps li {
  display: grid;
  grid-template-columns: 28px 1fr;
  gap: 12px;
}

.safety-steps li > span {
  display: grid;
  place-items: center;
  width: 28px;
  height: 28px;
  color: #c7d2fe;
  font: 700 11px/1 'SF Mono', ui-monospace, monospace;
  background: rgba(99, 102, 241, 0.18);
  border-radius: 8px;
}

.safety-steps strong {
  display: block;
  margin: 2px 0 4px;
  font-size: 14px;
}

.format-note {
  display: grid;
  gap: 6px;
  padding-top: 18px;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.format-note span {
  color: rgba(255, 255, 255, 0.48);
  font-size: 11px;
}

.format-note strong {
  color: #a5b4fc;
  font: 700 12px/1.5 'SF Mono', ui-monospace, monospace;
}

@media (max-width: 900px) {
  .create-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 520px) {
  .form-panel :deep(.el-card__body),
  .safety-panel {
    padding: 20px;
  }

  .form-actions {
    align-items: stretch;
    flex-direction: column-reverse;
  }

  .form-actions .el-button {
    width: 100%;
    margin: 0;
  }
}
</style>
