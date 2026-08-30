import api from './index'
import { createMusicImportApi } from './musicImportClient'

export { createMusicImportApi, getAvailableMusicImportActions } from './musicImportClient'

const musicImports = createMusicImportApi(api)

export default musicImports
