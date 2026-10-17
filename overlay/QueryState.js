// Pure helpers: shared by the QML overlay and its dependency-free tests.
function options(query, category, offset) {
  var types = []
  if (category === "code") types = ["code", "json"]
  else if (category === "text") types = ["text", "email", "phone", "number", "file", "path"]
  else if (category !== "all" && category !== "pinned") types = [category]
  return { query: query.trim(), types: types, pinned_only: category === "pinned", limit: 200, offset: offset || 0 }
}
function isCurrent(requestGeneration, currentGeneration) {
  return requestGeneration === currentGeneration
}
function canAppend(requestGeneration, currentGeneration, offset, length) {
  return isCurrent(requestGeneration, currentGeneration) && offset === length
}
function mayPrefetch(item) {
  return item && item.sensitive !== true
}
function computeNavigation(currentIndex, delta, totalCount, hasMore, threshold) {
  if (totalCount <= 0) return { index: 0, shouldLoad: false }
  var thresh = typeof threshold === "number" ? threshold : 6
  var target = currentIndex + delta
  var shouldLoad = (target >= totalCount - thresh) && hasMore === true

  if (target >= totalCount) {
    if (hasMore) {
      return { index: totalCount - 1, shouldLoad: true }
    }
    return { index: 0, shouldLoad: false }
  }
  if (target < 0) {
    return { index: totalCount - 1, shouldLoad: false }
  }
  return { index: target, shouldLoad: shouldLoad }
}
