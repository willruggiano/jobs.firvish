local function s(n)
  return string.rep(" ", n)
end

local JobInfo = {}
JobInfo.__index = JobInfo

JobInfo.format_string = table.concat {
  "%s", -- id
  s(1),
  "%s", -- job output buffer: (a)ctive or (h)idden
  "%s", -- job status: (R)unning or (F)inished
  "%s", -- exit status: x for non-zero exit code
  s(2),
  "%s", -- commandline
}

function JobInfo.new(job)
  local obj = { handle = job }
  return setmetatable(obj, JobInfo)
end

function JobInfo:id()
  return self.handle.id
end

function JobInfo:active()
  return false
end

function JobInfo:start_time()
  return self.handle.start_time_
end

function JobInfo:end_time()
  return self.handle.end_time_
end

function JobInfo:running()
  return self.handle.running == true
end

function JobInfo:finished()
  return self.handle.running == false
end

function JobInfo:status()
  return self.handle.exit_code
end

function JobInfo:commandline()
  return string.format([["%s"]], self.handle.commandline)
end

function JobInfo:deconstruct(opts)
  local text = {}
  local pid = self.handle:pid()
  if pid then
    table.insert(text, "pid " .. pid)
  end
  if opts.sort then
    local prefix = self:running() and "started" or "finished"
    local value = self:running() and self.handle:start_time() or self.handle:end_time()
    table.insert(text, prefix .. ": " .. value)
  end
  if self:finished() then
    table.insert(text, "status: " .. self:status())
  end
  local n = string.len(tostring(self.handle.id))
  return {
    line = string.format(
      JobInfo.format_string,
      s(3 - n) .. tostring(self.handle.id),
      self:active() and "a" or "h",
      self:running() and "R" or "F",
      self:status() ~= 0 and "x" or s(1),
      self:commandline()
    ),
    extmark = {
      opts = {
        virt_text = {
          {
            "(" .. table.concat(text, "; ") .. ")",
            self:finished() and self:status() ~= 0 and "Error" or "Comment",
          },
        },
        virt_text_pos = "right_align",
      },
    },
  }
end

return JobInfo
