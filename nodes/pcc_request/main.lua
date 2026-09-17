-- PCC Request — Transform
--
-- The generic way through to PointClickCare. Takes a request descriptor, makes
-- the authenticated call, and passes the response on.
--
-- This is what keeps the adapter reusable. It has no opinion about what is being
-- read or written, so any workflow can use it without this node having to learn
-- that workflow's domain. An adapter that knew about glucose observations would
-- only ever suit glucose observations.
--
-- Input message (JSON):
--
--   { "method": "GET",                       -- GET or POST, default GET
--     "path":   "/orgs/<orgUuid>/facs",      -- required; may use {orgUuid}
--     "query":  { "facId": 12 },             -- optional
--     "body":   { ... },                     -- optional, POST only
--     "correlationId": "..." }               -- optional, echoed back
--
-- {orgUuid} in the path is substituted with the organization the token belongs
-- to, so a caller does not need to know it up front. PointClickCare returns the
-- organization with the token rather than accepting it as input.
--
-- Output message (JSON): the same descriptor plus status, and either json or an
-- error. Failures are emitted rather than raised, except for the retryable kinds
-- where raising lets the runtime redeliver.
local PCC    = require 'pcc_api'
local PCCcfg = require 'pcc_api_config'

local function emit(msg)
   linkiir.flow.push{ data = linkiir.json.serialize(msg) }
end

function main(Data)
   local client, cfg = PCCcfg.fromNodeConfig()

   local ok, req = pcall(linkiir.json.parse, Data or '')
   if not ok or type(req) ~= 'table' then
      linkiir.log.warn('PCC Request: input was not a JSON object; dropping it')
      emit{ type = 'PCC_RESPONSE', ok = false,
            error = 'input was not a JSON object' }
      return
   end

   local path = req.path
   if type(path) ~= 'string' or path == '' then
      emit{ type = 'PCC_RESPONSE', ok = false,
            correlationId = req.correlationId,
            error = 'request is missing "path"' }
      return
   end

   local gaps = PCCcfg.missing(cfg)
   if gaps then
      emit{ type = 'PCC_RESPONSE', ok = false, correlationId = req.correlationId,
            error = 'adapter is not configured yet: ' .. gaps }
      return
   end

   local tok, terr = client:connect()
   if not tok then
      if PCC.isRetryable(terr) then
         error('PCC Request: ' .. terr.message)
      end
      emit{ type = 'PCC_RESPONSE', ok = false, correlationId = req.correlationId,
            error = terr.message, kind = terr.kind }
      return
   end
   if tok.simulated then
      emit{ type = 'PCC_RESPONSE', ok = false, simulated = true,
            correlationId = req.correlationId,
            error = 'Live Mode is off, so no request was sent' }
      return
   end

   -- Substitute {orgUuid} so callers need not carry it.
   local org = client:orgUuid()
   if org and org ~= '' then
      path = path:gsub('{orgUuid}', org)
   elseif path:find('{orgUuid}', 1, true) then
      emit{ type = 'PCC_RESPONSE', ok = false, correlationId = req.correlationId,
            error = 'path needs {orgUuid} but the organization is unknown' }
      return
   end

   local method = string.upper(tostring(req.method or 'GET'))
   if method ~= 'GET' and method ~= 'POST' then
      emit{ type = 'PCC_RESPONSE', ok = false, correlationId = req.correlationId,
            error = 'unsupported method "' .. method .. '": use GET or POST' }
      return
   end

   local res, err = client:request{
      method = method, path = path,
      query = (type(req.query) == 'table') and req.query or nil,
      body  = (method == 'POST') and req.body or nil,
   }

   if not res then
      if PCC.isRetryable(err) then
         -- Redelivery is worth it for a throttle or a server fault.
         error('PCC Request: ' .. err.message)
      end
      linkiir.log.warn('PCC Request: ' .. method .. ' ' .. path .. ' -> ' .. err.message)
      emit{ type = 'PCC_RESPONSE', ok = false, correlationId = req.correlationId,
            method = method, path = path,
            status = err.status, kind = err.kind, error = err.message }
      return
   end

   linkiir.log.info('PCC Request: ' .. method .. ' ' .. path ..
                    ' -> HTTP ' .. tostring(res.status))

   emit{
      type          = 'PCC_RESPONSE',
      ok            = true,
      correlationId = req.correlationId,
      createdAt     = os.date('!%Y-%m-%dT%H:%M:%SZ'),
      method        = method,
      path          = path,
      status        = res.status,
      json          = res.json,
   }
end
