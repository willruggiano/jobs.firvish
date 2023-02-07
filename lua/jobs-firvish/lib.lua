local Buffer = require "firvish.buffer"

local lib = {}

---@param buffer Buffer
---@param joblist JobList
function lib.refresh(buffer, joblist)
  buffer:set_lines(joblist:lines())
  buffer.options.modified = false
end

return lib
