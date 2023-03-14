---@tag jobs.firvish

local lib = require "jobs-firvish.lib"

local Buffer = require "firvish.types.buffer"
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
  jobs.config = vim.tbl_deep_extend("force", jobs.config, opts)

  vim.filetype.add {
    filename = {
      [jobs.filename] = "firvish-jobs",
    },
  }

  ---@tag :Jobs
  ---@brief [[
  ---Open the job list.
  ---@brief ]]
  vim.api.nvim_create_user_command("Jobs", function()
    vim.cmd(jobs.config.open .. " " .. jobs.filename)
    jobs.setup_buffer(vim.api.nvim_get_current_buf())
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
  local buffer = Buffer:new(bufnr)
  buffer:set_options {
    bufhidden = "wipe",
    buflisted = false,
    buftype = "acwrite",
    swapfile = false,
  }

  local config = jobs.config
  local default_opts = { buffer = bufnr, noremap = true, silent = true }
  for mode, mappings in pairs(config.keymaps) do
    for lhs, opts in pairs(mappings) do
      if opts then
        vim.keymap.set(mode, lhs, opts.callback, vim.tbl_extend("force", default_opts, opts))
      end
    end
  end

  lib.refresh(get_joblist(), buffer)

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    buffer = bufnr,
    callback = function()
      lib.refresh(get_joblist(), buffer)
    end,
  })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function()
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
      buffer:set_option("modified", false)
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    buffer = bufnr,
    callback = function()
      lib.refresh(buffer)
    end,
  })
end

return jobs
