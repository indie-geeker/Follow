import api from './index'
import { createMusicImportApi } from './musicImportClient'

export {
  createMusicImportApi,
  getAvailableMusicImportActions,
  parseMusicImportReviewGroup,
  parseMusicImportReviewPage
} from './musicImportClient'

const musicImports = createMusicImportApi(api)

export default musicImports
