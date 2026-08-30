export interface LatestRequestGate {
  begin: () => number
  isLatest: (token: number) => boolean
  invalidate: () => void
}

export function createLatestRequestGate(): LatestRequestGate {
  let latestToken = 0

  return {
    begin() {
      latestToken += 1
      return latestToken
    },
    isLatest(token) {
      return token === latestToken
    },
    invalidate() {
      latestToken += 1
    }
  }
}
