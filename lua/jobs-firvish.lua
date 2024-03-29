---@mod jobs-firvish
---@brief [[
---Like |:ls| but for Firvish jobs.
---
---Setup:
--->
---require("firvish").setup()
---require("jobs-firvish").setup()
---<
---
---Invoke via |:Firvish|:
---
--->
---:Firvish[!] jobs [flags]
---<
---
---[!] will invert the behavior of [flags].
---
---Indicators (chars in the same column are mutually exclusive):
---a       an active job-output buffer: it is loaded and visible
---h       a hidden job-output buffer: it is loaded, but currently not
---           displayed in a window
--- R      a running job
--- F      a finished job
---  x     a job that exited with a non-zero exit code
---
---[flags] can be a combination of the following characters,
---which restrict the jobs to be listed:
---        a       active job-output buffers
---        h       hidden job-output buffers
---        R       runnings jobs
---        F       finished jobs
---        x       jobs that exited with a non-zero exit code
---        t       show start-time or end-time (if 'F') and sort jobs
---Combining flags means they are "and"ed together, e.g.:
---        Fx      finished jobs that exited with a non-zero exit code
---When [!] is included, combining flags means they are "or"ed together.
---
---Invoke via `firvish.extensions`:
---
--->
---require("firvish").extensions.jobs:open()
----- or, to pass arguments (e.g. flags)
---require("firvish").extensions.jobs:run { ... }
---<
---
---@brief ]]

---@tag :Run
---@brief [[
---Usage: ~
---
---  :Run[!] {cmd} [args]
---
---  Spawns {cmd} in the background.
---  If [!] is given, redirect the output of {cmd} to the errorlist
---  (quickfix by default).
---  [args] are |expand()|ed before being passed to {cmd}
---@brief ]]

---@tag :Start
---@brief [[
---Usage: ~
---
---  :Start {cmd} [args]
---
---  Spawns {cmd} in the foreground, i.e. the job-output buffer is
---  opened in the current window as soon as {cmd} starts.
---  [args] are |expand()|ed before being passed to {cmd}
---@brief ]]

local Filter = require "firvish.filter"
local JobInfo = require "jobs-firvish.jobinfo"

local namespace = vim.api.nvim_create_namespace "jobs-firvish"

local function reconstruct(line)
  local match = string.match(line, "(%d+)")
  if match ~= nil then
    return tonumber(match)
  else
    error("Failed to parse line: '" .. line .. "'")
  end
end

local function job_from_line(line)
  local job_id = reconstruct(line)
  local job = require("firvish").getjobinfo(job_id)[1]
  return JobInfo.new(job)
end

local function reconstruct_from_buffer(buffer)
  local jobs = {}
  for _, line in ipairs(buffer:get_lines()) do
    table.insert(jobs, job_from_line(line))
  end
  return jobs
end

local flag_values = {
  ["R"] = Filter.new(function(jobinfo)
    return jobinfo:running()
  end),
  ["F"] = Filter.new(function(jobinfo)
    return jobinfo:finished()
  end),
}

local function make_filter_fn(flags, invert)
  local filter = Filter.new(function()
    return true
  end)

  for pattern, fn in pairs(flag_values) do
    if string.match(flags, pattern) then
      if invert then
        ---@diagnostic disable-next-line: cast-local-type
        filter = filter - fn
      else
        ---@diagnostic disable-next-line: cast-local-type
        filter = filter + fn
      end
    end
  end

  return filter
end

local function filter(flags, invert)
  if flags then
    return make_filter_fn(flags, invert)
  else
    return function()
      return true
    end
  end
end

local function maybe_sort(jobs, flags)
  if flags and string.match(flags, "t") then
    table.sort(jobs, function(j0, j1)
      local lhs, rhs
      if j0:running() then
        lhs = j0:start_time()
      else
        lhs = j0:end_time()
      end
      if j1:running() then
        rhs = j1:start_time()
      else
        rhs = j1:end_time()
      end
      return lhs > rhs
    end)
  end
  return jobs
end

local function list_jobs(flags, invert)
  local jobs = vim.tbl_map(JobInfo.new, require("firvish").getjobinfo())
  ---@diagnostic disable-next-line: param-type-mismatch
  return maybe_sort(vim.tbl_filter(filter(flags, invert), jobs), flags)
end

local function set_lines(buffer, flags, invert)
  vim.api.nvim_buf_clear_namespace(buffer.bufnr, namespace, 0, -1)

  local lines = {}
  local extmarks = {}
  for _, jobinfo in ipairs(list_jobs(flags, invert)) do
    local repr = jobinfo:deconstruct {
      sort = flags and string.match(flags, "t") and true or false,
    }
    table.insert(lines, repr.line)
    if repr.extmark then
      table.insert(
        extmarks,
        vim.tbl_deep_extend("force", {
          ns_id = namespace,
          line = #lines - 1,
          col = -1,
        }, repr.extmark)
      )
    end
  end

  buffer:set_lines(lines, {}, extmarks)
  buffer.opt.modified = false
end

local function make_lookup_table(jobs)
  local lookup = {}
  for _, jobinfo in ipairs(jobs) do
    lookup[tostring(jobinfo:id())] = jobinfo
  end
  return lookup
end

---@param original JobInfo[]
---@param target JobInfo[]
local function compute_difference(original, target)
  local lookup = make_lookup_table(target)
  local diff = {}
  for _, jobinfo in ipairs(original) do
    if lookup[tostring(jobinfo:id())] == nil then
      table.insert(diff, jobinfo:id())
    end
  end
  return diff
end

---@package
local Extension = {}
Extension.__index = Extension

---@package
Extension.bufname = "firvish://jobs"

---@package
function Extension.new()
  local obj = {}

  obj.keymaps = {
    n = {
      ["<CR>"] = {
        callback = function()
          error "not yet implemented"
        end,
        desc = "Open the job under the cursor",
      },
    },
  }
  obj.options = {
    bufhidden = "hide",
    filetype = "firvish-jobs",
  }

  return setmetatable(obj, Extension)
end

---@package
function Extension:on_buf_enter(buffer)
  set_lines(buffer)
end

---@package
function Extension:on_buf_write_cmd(buffer)
  local current = list_jobs()
  local desired = reconstruct_from_buffer(buffer)
  local diff = compute_difference(current, desired)
  for _, job_id in ipairs(diff) do
    require("firvish").delete_job(job_id)
  end
  buffer.opt.modified = false
end

---@package
function Extension:on_buf_write_post(buffer)
  set_lines(buffer)
end

---@package
function Extension:execute(buffer, args)
  buffer:open(args.how)
  if args.fargs then
    set_lines(buffer, args.fargs[2], args.bang)
  else
    set_lines(buffer)
  end
end

local M = {}

function M.setup()
  require("firvish").register_extension("jobs", Extension.new())

  vim.api.nvim_create_user_command("Run", function(args)
    require("firvish").start_job {
      command = args.fargs[1],
      args = vim.tbl_map(vim.fn.expand, vim.list_slice(args.fargs, 2)),
      bopen = false,
      errorlist = args.bang and "quickfix" or false,
      eopen = args.bang,
    }
  end, { bang = true, desc = "Spawn an external command in the background", nargs = "+" })

  vim.api.nvim_create_user_command("Start", function(args)
    require("firvish").start_job {
      command = args.fargs[1],
      args = vim.tbl_map(vim.fn.expand, vim.list_slice(args.fargs, 2)),
      bopen = true,
    }
  end, { bang = true, desc = "Spawn an external command", nargs = "+" })
end

return M
