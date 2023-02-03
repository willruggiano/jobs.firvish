local Buffer = require "firvish.types.buffer"

local lib = {}

---@param joblist JobList
---@param buffer? Buffer
function lib.refresh(joblist, buffer)
  if buffer == nil then
    buffer = Buffer:new(vim.api.nvim_get_current_buf())
  end
  buffer:set_lines(joblist:lines())
  buffer:set_option("modified", false)
end

return lib
