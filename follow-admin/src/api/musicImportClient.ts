import type { AxiosInstance } from 'axios'
import type {
  CreateMusicImportRequest,
  MusicImportAction,
  MusicImportBatchDetail,
  MusicImportBatchListParams,
  MusicImportBatchListResponse,
  MusicImportBatchStatus,
  MusicImportCapabilities,
  MusicImportItemListParams,
  MusicImportItemListResponse
} from '@/types/musicImport'

const BASE_PATH = '/api/admin/music-imports'

export function getAvailableMusicImportActions(
  status: MusicImportBatchStatus,
  retryableFailed: number
): MusicImportAction[] {
  switch (status) {
    case 'pending':
    case 'scanning':
      return ['cancel']
    case 'ready':
      return ['start', 'cancel']
    case 'running':
      return ['pause', 'cancel']
    case 'pauseRequested':
      return ['cancel']
    case 'paused':
      return ['resume', 'cancel']
    case 'completedWithErrors':
      return retryableFailed > 0 ? ['retryFailures'] : []
    default:
      return []
  }
}

export function createMusicImportApi(client: Pick<AxiosInstance, 'get' | 'post'>) {
  return {
    async getCapabilities(): Promise<MusicImportCapabilities> {
      const response = await client.get<MusicImportCapabilities>(`${BASE_PATH}/capabilities`)
      return response.data
    },

    async listBatches(params: MusicImportBatchListParams): Promise<MusicImportBatchListResponse> {
      const response = await client.get<MusicImportBatchListResponse>(BASE_PATH, { params })
      return response.data
    },

    async createBatch(request: CreateMusicImportRequest): Promise<MusicImportBatchDetail> {
      const response = await client.post<MusicImportBatchDetail>(BASE_PATH, request)
      return response.data
    },

    async getBatch(batchId: string): Promise<MusicImportBatchDetail> {
      const response = await client.get<MusicImportBatchDetail>(`${BASE_PATH}/${batchId}`)
      return response.data
    },

    async listItems(
      batchId: string,
      params: MusicImportItemListParams
    ): Promise<MusicImportItemListResponse> {
      const response = await client.get<MusicImportItemListResponse>(
        `${BASE_PATH}/${batchId}/items`,
        { params }
      )
      return response.data
    },

    async start(batchId: string): Promise<MusicImportBatchDetail> {
      const response = await client.post<MusicImportBatchDetail>(`${BASE_PATH}/${batchId}/start`)
      return response.data
    },

    async pause(batchId: string): Promise<MusicImportBatchDetail> {
      const response = await client.post<MusicImportBatchDetail>(`${BASE_PATH}/${batchId}/pause`)
      return response.data
    },

    async resume(batchId: string): Promise<MusicImportBatchDetail> {
      const response = await client.post<MusicImportBatchDetail>(`${BASE_PATH}/${batchId}/resume`)
      return response.data
    },

    async cancel(batchId: string): Promise<MusicImportBatchDetail> {
      const response = await client.post<MusicImportBatchDetail>(`${BASE_PATH}/${batchId}/cancel`)
      return response.data
    },

    async retryFailures(batchId: string): Promise<MusicImportBatchDetail> {
      const response = await client.post<MusicImportBatchDetail>(
        `${BASE_PATH}/${batchId}/retry-failures`
      )
      return response.data
    }
  }
}
