import request from './request'

export function fetchHealth() {
  return request.get('/v1/health')
}
