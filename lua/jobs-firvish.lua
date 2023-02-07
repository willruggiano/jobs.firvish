---@tag jobs.firvish

local firvish = require "firvish"
local lib = require "jobs-firvish.lib"

local Buffer = require "firvish.buffer"
local JobList = require "firvish.types.joblist"

local function get_joblist()
  return require("firvish.lib.jobs").get_joblist()
end

local jobs = {}

jobs.config = {
  open = "split",
  keymaps = {
    n = {
      ["-"] = {
        callback = function()
          vim.cmd.bwipeout()
        end,
        desc = "Close the joblist",
      },
    },
  },
}

jobs.filename = "firvish://jobs"

function jobs.setup(opts)
  jobs.config = vim.tbl_deep_extend("force", jobs.config, opts or {})

  firvish.extension.register("jobs", {
    -- TODO: Something like this?
    -- buffer = {
    --   on_enter = function(buffer)
    --     lib.refresh(get_joblist(), buffer)
    --   end,
    --   on_exit = function(buffer)
    --     --
    --   end,
    --   on_write = function(buffer, old, new)
    --     local lines = buffer:get_lines()
    --     local current = get_joblist()
    --     local desired = JobList.parse(lines)
    --     local diff = current / desired
    --     for i, job in diff:iter() do
    --       if job.running then
    --         job:stop()
    --       end
    --       current:remove(i)
    --     end
    --     return false --> buffer.options.modified
    --   end,
    -- },
    config = jobs.config,
    filetype = {
      filename = jobs.filename,
      filetype = function(_, bufnr)
        jobs.setup_buffer(bufnr)
      end,
    },
  })

  ---@tag :Jobs
  ---@brief [[
  ---Open the job list.
  ---@brief ]]
  vim.api.nvim_create_user_command("Jobs", function()
    vim.cmd(jobs.config.open .. " " .. jobs.filename)
  end, {
    desc = "Open the joblist",
  })

  ---@tag :Run
  ---@brief [[
  ---Run an external command.
  ---@brief ]]
  vim.api.nvim_create_user_command("Run", function(args)
    require("firvish").start_job {
      command = args.fargs[1],
      args = vim.list_slice(args.fargs, 2),
      filetype = "log",
      title = args.fargs[1],
      errorlist = "quickfix",
      eopen = args.bang,
      bopen = args.bang and { headers = false, open = false } or true,
    }
  end, { bang = true, desc = "Run an external command", nargs = "+" })
end

function jobs.setup_buffer(bufnr)
  local buffer = Buffer.new(bufnr)

  lib.refresh(buffer, get_joblist())

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    buffer = bufnr,
    callback = function()
      lib.refresh(buffer, get_joblist())
    end,
  })

  -- TODO: How can this be genericized?
  buffer:create_autocmd("BufWriteCmd", function()
    local lines = buffer:get_lines()
    local current = get_joblist()
    local desired = JobList.parse(lines)
    local diff = current / desired
    for i, job in diff:iter() do
      if job.running then
        job:stop()
      end
      current:remove(i)
    end
    buffer.options.modified = false
  end)
  -- perhaps...
  -- buffer:on_write(function(old, new)
  --   -- Take action. Perhaps by computing the diff...
  --   -- e.g. delete the corresponding job for each removed line
  -- end)

  buffer:create_autocmd("BufWritePost", function()
    lib.refresh(buffer, get_joblist())
  end)
end

return jobs
