import type { App, Plugin } from 'vue'
import {
  ElAside,
  ElAvatar,
  ElButton,
  ElCard,
  ElCheckbox,
  ElCol,
  ElContainer,
  ElDialog,
  ElDropdown,
  ElDropdownItem,
  ElDropdownMenu,
  ElForm,
  ElFormItem,
  ElHeader,
  ElIcon,
  ElImage,
  ElInput,
  ElInputNumber,
  ElLoading,
  ElMain,
  ElMenu,
  ElMenuItem,
  ElOption,
  ElPagination,
  ElRadio,
  ElRow,
  ElSelect,
  ElTable,
  ElTableColumn,
  ElTag,
  ElUpload
} from 'element-plus'

import 'element-plus/es/components/aside/style/css'
import 'element-plus/es/components/avatar/style/css'
import 'element-plus/es/components/button/style/css'
import 'element-plus/es/components/card/style/css'
import 'element-plus/es/components/checkbox/style/css'
import 'element-plus/es/components/col/style/css'
import 'element-plus/es/components/container/style/css'
import 'element-plus/es/components/dialog/style/css'
import 'element-plus/es/components/dropdown/style/css'
import 'element-plus/es/components/form/style/css'
import 'element-plus/es/components/form-item/style/css'
import 'element-plus/es/components/header/style/css'
import 'element-plus/es/components/icon/style/css'
import 'element-plus/es/components/image/style/css'
import 'element-plus/es/components/input/style/css'
import 'element-plus/es/components/input-number/style/css'
import 'element-plus/es/components/loading/style/css'
import 'element-plus/es/components/main/style/css'
import 'element-plus/es/components/menu/style/css'
import 'element-plus/es/components/menu-item/style/css'
import 'element-plus/es/components/message/style/css'
import 'element-plus/es/components/message-box/style/css'
import 'element-plus/es/components/option/style/css'
import 'element-plus/es/components/pagination/style/css'
import 'element-plus/es/components/radio/style/css'
import 'element-plus/es/components/radio-button/style/css'
import 'element-plus/es/components/radio-group/style/css'
import 'element-plus/es/components/row/style/css'
import 'element-plus/es/components/select/style/css'
import 'element-plus/es/components/table/style/css'
import 'element-plus/es/components/table-column/style/css'
import 'element-plus/es/components/tag/style/css'
import 'element-plus/es/components/upload/style/css'

const components = [
  ElAside,
  ElAvatar,
  ElButton,
  ElCard,
  ElCheckbox,
  ElCol,
  ElContainer,
  ElDialog,
  ElDropdown,
  ElDropdownItem,
  ElDropdownMenu,
  ElForm,
  ElFormItem,
  ElHeader,
  ElIcon,
  ElImage,
  ElInput,
  ElInputNumber,
  ElLoading,
  ElMain,
  ElMenu,
  ElMenuItem,
  ElOption,
  ElPagination,
  ElRadio,
  ElRow,
  ElSelect,
  ElTable,
  ElTableColumn,
  ElTag,
  ElUpload
]

export function installElementPlus(app: App): void {
  for (const component of components) {
    app.use(component as Plugin)
  }
}
