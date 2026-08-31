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
  MusicImportItemListResponse,
  MusicImportLockRequest,
  MusicImportReviewBatchState,
  MusicImportReviewCandidate,
  MusicImportReviewDecisionRequest,
  MusicImportReviewGroup,
  MusicImportReviewPage,
  MusicImportReviewPageParams,
  MusicImportUploadAccepted
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

export function createMusicImportApi(client: Pick<AxiosInstance, 'get' | 'post' | 'put'>) {
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

    async uploadBrowserFile(
      file: File,
      clientRequestId: string,
      onUploadProgress?: (loaded: number, total?: number) => void
    ): Promise<MusicImportUploadAccepted> {
      const formData = new FormData()
      formData.append('file', file)
      const response = await client.post<MusicImportUploadAccepted>(
        `${BASE_PATH}/uploads`,
        formData,
        {
          params: { clientRequestId },
          ...(onUploadProgress
            ? {
                onUploadProgress: (event: { loaded: number; total?: number }) =>
                  onUploadProgress(event.loaded, event.total)
              }
            : {})
        }
      )
      if (response.status !== 202) {
        throw new Error('Music upload was not accepted for review.')
      }
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

    async listReviewGroups(
      batchId: string,
      params: MusicImportReviewPageParams
    ): Promise<MusicImportReviewPage> {
      const response = await client.get<unknown>(`${BASE_PATH}/${batchId}/review-groups`, {
        params
      })
      return parseMusicImportReviewPage(response.data)
    },

    async getReviewGroup(groupId: string): Promise<MusicImportReviewGroup> {
      const response = await client.get<unknown>(`${BASE_PATH}/review-groups/${groupId}`)
      return parseMusicImportReviewGroup(response.data)
    },

    async saveReviewDecision(
      groupId: string,
      request: MusicImportReviewDecisionRequest
    ): Promise<MusicImportReviewGroup> {
      const response = await client.put<unknown>(
        `${BASE_PATH}/review-groups/${groupId}/decision`,
        request
      )
      return parseMusicImportReviewGroup(response.data)
    },

    async applyReview(
      batchId: string,
      request: MusicImportLockRequest
    ): Promise<MusicImportReviewBatchState> {
      const response = await client.post<MusicImportReviewBatchState>(
        `${BASE_PATH}/${batchId}/apply`,
        request
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

const reviewStatuses = new Set([
  'open',
  'confirmed',
  'locked',
  'applied',
  'deferred',
  'conflict',
  'failed'
])
const matchKinds = new Set(['none', 'exactSha256', 'acousticFingerprint', 'userSeparated'])
const decisionKinds = new Set([
  'createTrack',
  'replaceExistingTrack',
  'keepExistingTrack',
  'treatAsSeparateRecording',
  'rejectDuplicate',
  'defer'
])
const sourceKinds = new Set(['mountedDirectory', 'browserStaging'])

export function parseMusicImportReviewGroup(value: unknown): MusicImportReviewGroup {
  const group = asRecord(value, 'review group')
  requireEnum(group.status, reviewStatuses, 'review status')
  requireEnum(group.matchKind, matchKinds, 'match kind')
  if (group.decisionKind !== null) {
    requireEnum(group.decisionKind, decisionKinds, 'decision kind')
  }
  if (!Array.isArray(group.selectedItemIds)) {
    throw new TypeError('Invalid selected item IDs.')
  }
  if (!Array.isArray(group.candidates)) {
    throw new TypeError('Invalid review candidates.')
  }
  const candidates = group.candidates.map(parseCandidate)
  return { ...group, candidates } as unknown as MusicImportReviewGroup
}

export function parseMusicImportReviewPage(value: unknown): MusicImportReviewPage {
  const page = asRecord(value, 'review page')
  if (!Array.isArray(page.groups)) throw new TypeError('Invalid review groups page.')
  asRecord(page.summary, 'review summary')
  return {
    ...page,
    groups: page.groups.map(parseMusicImportReviewGroup)
  } as unknown as MusicImportReviewPage
}

function parseCandidate(value: unknown): MusicImportReviewCandidate {
  const candidate = asRecord(value, 'review candidate')
  requireEnum(candidate.sourceKind, sourceKinds, 'source kind')
  if (candidate.decision !== null) {
    requireEnum(candidate.decision, decisionKinds, 'candidate decision')
  }
  return candidate as unknown as MusicImportReviewCandidate
}

function asRecord(value: unknown, label: string): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new TypeError(`Invalid ${label}.`)
  }
  return value as Record<string, unknown>
}

function requireEnum(value: unknown, allowed: Set<string>, label: string): asserts value is string {
  if (typeof value !== 'string' || !allowed.has(value)) {
    throw new TypeError(`Invalid ${label}.`)
  }
}
