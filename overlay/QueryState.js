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
