-- pcc_api_config.lua — bridge from a node's config to a PointClickCare client,
-- so every node in the adapter builds one the same way.
--
--   local client, cfg = require('pcc_api_config').fromNodeConfig()
--
-- cfg is the raw linkiir.config.node() map, returned as well because each node
-- has its own extra fields.
local PCC = require 'pcc_api'

local M = {}

-- Host defaults per grant. These are not interchangeable, and picking the wrong
-- one is the single most common way a first connection fails:
--   two-legged lives on connect2 and enforces mutual TLS
--   three-legged lives on connect and uses no client certificate
M.DEFAULTS = {
   ['2-legged'] = {
      authBase = 'https://connect2.pointclickcare.com',
      apiBase  = 'https://connect2.pointclickcare.com/api/public/preview1',
   },
   ['3-legged'] = {
      authBase = 'https://connect.pointclickcare.com',
      apiBase  = 'https://connect.pointclickcare.com/api/public/preview1',
   },
}

-- Config values may arrive as a bool or as a string; be forgiving.
local function toBool(v, default)
   if v == nil then return default end
   if type(v) == 'boolean' then return v end
   if type(v) == 'string' then return v:lower() == 'true' end
   return default
end

local function blankToNil(v)
   if v == nil then return nil end
   v = tostring(v)
   if v == '' then return nil end
   return v
end

--- Normalise the OAuth mode, defaulting to two-legged.
function M.mode(cfg)
   local raw = tostring(cfg['OAuth Mode'] or ''):lower()
   if raw:find('3', 1, true) or raw:find('three', 1, true) then return '3-legged' end
   return '2-legged'
end

function M.fromNodeConfig()
   local cfg = linkiir.config.node()
   local mode = M.mode(cfg)
   local defaults = M.DEFAULTS[mode]

   -- Leaving the base URLs blank is the normal case: the right host follows
   -- from the grant, so the adapter fills it in rather than making the importer
   -- look it up and risk pairing a grant with the wrong host.
   local client = PCC.client{
      mode         = mode,
      authBase     = blankToNil(cfg['Auth Base URL']) or defaults.authBase,
      apiBase      = blankToNil(cfg['API Base URL'])  or defaults.apiBase,
      clientId     = cfg['Client ID'],
      clientSecret = cfg['Client Secret'],
      redirectUri  = blankToNil(cfg['Redirect URI']),
      certFile     = blankToNil(cfg['Client Certificate File']),
      keyFile      = blankToNil(cfg['Client Key File']),
      caFile       = blankToNil(cfg['CA File']),
      orgUuid      = blankToNil(cfg['Organization UUID']),
      timeout      = tonumber(cfg['Request Timeout']) or 20,
      verifyTls    = toBool(cfg['Verify TLS'], true),
      live         = toBool(cfg['Live Mode'], false),
   }
   return client, cfg
end

--- Report what is still missing, so a node can say so once at startup instead
-- of failing on every cycle with a transport error.
function M.missing(cfg)
   local mode = M.mode(cfg)
   local gaps = {}
   if blankToNil(cfg['Client ID']) == nil then gaps[#gaps + 1] = 'Client ID' end
   if blankToNil(cfg['Client Secret']) == nil then gaps[#gaps + 1] = 'Client Secret' end
   if mode == '2-legged' then
      if blankToNil(cfg['Client Certificate File']) == nil then
         gaps[#gaps + 1] = 'Client Certificate File (required for 2-legged)'
      end
      if blankToNil(cfg['Client Key File']) == nil then
         gaps[#gaps + 1] = 'Client Key File (required for 2-legged)'
      end
   else
      if blankToNil(cfg['Redirect URI']) == nil then
         gaps[#gaps + 1] = 'Redirect URI (required for 3-legged)'
      end
   end
   if #gaps == 0 then return nil end
   return table.concat(gaps, ', ')
end

return M
