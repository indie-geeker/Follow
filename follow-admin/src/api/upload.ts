import type {
  UploadProgressEvent,
  UploadRequestHandler,
  UploadRequestOptions
} from 'element-plus/es/components/upload/src/upload'
import api from './index'
import musicImports from './musicImports'

function appendUploadData(formData: FormData, data: UploadRequestOptions['data']): void {
  for (const [key, value] of Object.entries(data)) {
    if (Array.isArray(value)) {
      formData.append(key, value[0], value[1])
    } else {
      formData.append(key, value)
    }
  }
}

export function createApiUpload(getUrl: () => string): UploadRequestHandler {
  return async (options) => {
    const formData = new FormData()
    appendUploadData(formData, options.data)
    formData.append(options.filename, options.file)

    try {
      const response = await api.post(getUrl(), formData, {
        onUploadProgress(event) {
          const progressEvent = new ProgressEvent('progress', {
            lengthComputable: event.total !== undefined,
            loaded: event.loaded,
            total: event.total ?? 0
          }) as UploadProgressEvent
          progressEvent.percent = event.total
            ? Math.min(100, Math.round((event.loaded * 100) / event.total))
            : 0
          options.onProgress(progressEvent)
        }
      })
      options.onSuccess(response.data)
      return response.data
    } catch (error) {
      options.onError(error as Parameters<UploadRequestOptions['onError']>[0])
      throw error
    }
  }
}

export function createMusicImportUpload(): UploadRequestHandler {
  return async (options) => {
    try {
      const accepted = await musicImports.uploadBrowserFile(
        options.file,
        crypto.randomUUID(),
        (loaded, total) => {
          const progressEvent = new ProgressEvent('progress', {
            lengthComputable: total !== undefined,
            loaded,
            total: total ?? 0
          }) as UploadProgressEvent
          progressEvent.percent = total
            ? Math.min(100, Math.round((loaded * 100) / total))
            : 0
          options.onProgress(progressEvent)
        }
      )
      options.onSuccess(accepted)
      return accepted
    } catch (error) {
      options.onError(error as Parameters<UploadRequestOptions['onError']>[0])
      throw error
    }
  }
}
