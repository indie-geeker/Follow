<template>
  <el-pagination
    v-model:current-page="currentPage"
    :page-size="pageSize"
    :total="total"
    :pager-count="5"
    layout="total, prev, pager, next"
    class="admin-pagination"
    @current-change="emit('current-change', $event)"
  />
</template>

<script setup lang="ts">
const currentPage = defineModel<number>('currentPage', { required: true })

defineProps<{
  pageSize: number
  total: number
}>()

const emit = defineEmits<{
  (event: 'current-change', page: number): void
}>()
</script>

<style scoped>
.admin-pagination {
  justify-content: flex-end;
  padding: 16px 20px;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.admin-pagination :deep(.btn-prev),
.admin-pagination :deep(.btn-next),
.admin-pagination :deep(.el-pager li) {
  min-width: 44px;
  height: 44px;
  margin: 0 2px;
  color: rgba(255, 255, 255, 0.7) !important;
  line-height: 44px;
  background: rgba(255, 255, 255, 0.05) !important;
  border-radius: 4px;
}

.admin-pagination :deep(.el-pager li.is-active) {
  color: #fff !important;
  font-weight: 700;
  background: var(--primary-color, #409eff) !important;
}

.admin-pagination :deep(.el-pagination__total) {
  margin-right: 12px;
  color: rgba(255, 255, 255, 0.6);
  font-variant-numeric: tabular-nums;
}

@media (max-width: 767px) {
  .admin-pagination {
    justify-content: center;
    padding: 12px 8px;
  }

  .admin-pagination :deep(.el-pagination__total) {
    display: none;
  }
}
</style>
