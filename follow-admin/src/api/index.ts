import { createHttpClient } from './httpClient'

const {
  api,
  refreshSession,
  setSessionExpiredHandler
} = createHttpClient({ withCredentials: true })

export {
  refreshSession,
  setSessionExpiredHandler
}

export default api
