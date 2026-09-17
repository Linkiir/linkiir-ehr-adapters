-- pcc_api.lua — public facade for the PointClickCare adapter.
--
--   local PCC = require 'pcc_api'
--   local client = PCC.client{
--      mode = '2-legged',                -- or '3-legged'
--      authBase = 'https://connect2.pointclickcare.com',
--      apiBase  = 'https://connect2.pointclickcare.com/api/public/preview1',
--      clientId = ..., clientSecret = ...,
--      certFile = ..., keyFile = ...,    -- required for 2-legged
--   }
--
--   client:connect()                     -- obtain a token; safe to call often
--   client:get{ path = '/orgs/<uuid>/facs' }
--   client:post{ path = '/orgs/<uuid>/patients/1/observations', body = {...} }
--   client:facilities()                  -- thin convenience wrappers
--   client:patients{ facId = 12 }
--   client:describe()                    -- one line for logs and banners
--
-- Every method returns result or nil, err. Nothing raises: whether a failure
-- should stop the flow is the node's decision, not the library's.
--
-- This adapter is about connectivity. It will authenticate, and it will make an
-- authenticated request to any path, but it deliberately holds no opinion about
-- what the payloads mean. Mapping a device reading into an observation body is
-- the integration's job, not the adapter's.
local http  = require 'pcc_api_http'
local oauth = require 'pcc_api_oauth'

local M = {}

local Client = {}
Client.__index = Client

-- Renew slightly early. A token that expires between the check and the request
-- produces a 401 that looks like a credential fault.
local EXPIRY_MARGIN_SECONDS = 120

--- Build a client. Nothing is contacted here.
function M.client(T)
   T = T or {}
   local conn = {
      mode         = (T.mode == '3-legged') and '3-legged' or '2-legged',
      authBase     = (tostring(T.authBase or '')):gsub('/+$', ''),
      apiBase      = (tostring(T.apiBase or '')):gsub('/+$', ''),
      clientId     = T.clientId,
      clientSecret = T.clientSecret,
      redirectUri  = T.redirectUri,
      certFile     = T.certFile,
      keyFile      = T.keyFile,
      caFile       = T.caFile,
      timeout      = tonumber(T.timeout) or 20,
      verifyTls    = T.verifyTls ~= false,
      live         = T.live == true,
      orgUuid      = T.orgUuid,
   }
   return setmetatable({
      conn  = conn,
      token = nil,   -- { accessToken, expiresAt, orgUuid } held in memory only
   }, Client)
end

--- What this client is configured to do, in one line for a log or a banner.
function Client:describe()
   local bits = { 'PointClickCare ' .. self.conn.mode }
   bits[#bits + 1] = (self.conn.live and 'live' or 'Live Mode off')
   if self.conn.mode == '2-legged' then
      bits[#bits + 1] = http.hasClientCert(self.conn)
         and 'client certificate set' or 'NO client certificate'
   end
   if self.token and self.token.expiresAt then
      local left = self.token.expiresAt - os.time()
      bits[#bits + 1] = (left > 0)
         and ('token valid ' .. tostring(math.floor(left / 60)) .. 'm')
         or 'token expired'
   else
      bits[#bits + 1] = 'no token yet'
   end
   return table.concat(bits, ' · ')
end

--- Is the cached token still usable?
function Client:hasValidToken()
   return self.token ~= nil
      and type(self.token.accessToken) == 'string'
      and self.token.accessToken ~= ''
      and (self.token.expiresAt or 0) - EXPIRY_MARGIN_SECONDS > os.time()
end

--- Obtain a token if the cached one is missing or close to expiry.
--
-- Only the two-legged grant can do this unattended, which is the whole reason
-- it is the default. A three-legged client cannot mint its own token, so it
-- reports what it needs instead of failing obscurely.
function Client:connect(force)
   if not force and self:hasValidToken() then return self.token end

   if self.conn.mode == '3-legged' then
      return nil, { kind = 'auth', status = 0,
                    message = 'three-legged mode cannot obtain a token on its own: ' ..
                              'complete the authorization redirect, then call ' ..
                              'setToken() with the stored tokens' }
   end

   local tok, err = oauth.clientCredentials(self.conn)
   if not tok then return nil, err end
   self.token = tok
   -- PointClickCare returns the org with the token; prefer it over configuration.
   if tok.orgUuid and tok.orgUuid ~= '' then self.conn.orgUuid = tok.orgUuid end
   return tok
end

--- Install a token obtained elsewhere, which is how a three-legged flow hands
-- its result to the client.
function Client:setToken(accessToken, expiresAt, orgUuid)
   self.token = { accessToken = accessToken, expiresAt = expiresAt, orgUuid = orgUuid }
   if orgUuid and orgUuid ~= '' then self.conn.orgUuid = orgUuid end
   return self.token
end

--- The organization UUID in play, whether configured or token-supplied.
function Client:orgUuid()
   return self.conn.orgUuid
end

-- --- requests --------------------------------------------------------------

local function buildUrl(conn, path, query)
   local url = conn.apiBase .. (path:sub(1, 1) == '/' and path or ('/' .. path))
   if type(query) == 'table' then
      local parts = {}
      for k, v in pairs(query) do
         parts[#parts + 1] = tostring(k) .. '=' ..
            linkiir.codec.uri.encode(tostring(v))
      end
      if #parts > 0 then
         url = url .. (url:find('?', 1, true) and '&' or '?') .. table.concat(parts, '&')
      end
   end
   return url
end

--- One authenticated request, with a single re-auth retry on 401.
--
-- The retry exists because a token can expire mid-flight. It is attempted once:
-- a second 401 means the credentials or privileges are wrong, and retrying a
-- permissions problem forever is how an adapter turns into a rate-limit
-- incident.
function Client:request(opts)
   local tok, err = self:connect()
   if not tok then return nil, err end

   local function attempt()
      return http.sendJson{
         method  = opts.method or 'GET',
         url     = buildUrl(self.conn, opts.path or '/', opts.query),
         conn    = self.conn,
         headers = {
            ['Authorization'] = 'Bearer ' .. tostring(self.token.accessToken),
            ['Accept']        = 'application/json',
            ['Content-Type']  = (opts.body ~= nil) and 'application/json' or nil,
         },
         body = (opts.body ~= nil) and linkiir.json.serialize(opts.body) or nil,
      }
   end

   local res, rerr = attempt()
   if res then return res end

   if rerr and rerr.kind == 'auth' and self.conn.mode == '2-legged' then
      local fresh, ferr = self:connect(true)
      if not fresh then return nil, ferr end
      return attempt()
   end
   return nil, rerr
end

function Client:get(opts)
   opts = opts or {}
   opts.method = 'GET'
   return self:request(opts)
end

function Client:post(opts)
   opts = opts or {}
   opts.method = 'POST'
   return self:request(opts)
end

-- --- thin resource helpers -------------------------------------------------
-- Convenience only. They exist because these three calls are how anyone proves
-- a connection works, not because the adapter models PointClickCare's domain.

--- The facilities in the organization. Useful first call: it proves the token,
-- the org and the transport all work, and it is how facId is discovered rather
-- than guessed. The number shown in the PointClickCare UI is usually the
-- facility *code*, not the facId the API wants.
function Client:facilities()
   local org = self.conn.orgUuid
   if not org or org == '' then
      return nil, { kind = 'client', status = 0,
                    message = 'organization UUID unknown: connect() first, or set it in config' }
   end
   return self:get{ path = '/orgs/' .. org .. '/facs' }
end

--- Current patients at a facility.
function Client:patients(opts)
   opts = opts or {}
   local org = self.conn.orgUuid
   if not org or org == '' then
      return nil, { kind = 'client', status = 0,
                    message = 'organization UUID unknown: connect() first, or set it in config' }
   end
   local query = { patientStatus = opts.status or 'Current' }
   if opts.facId then query.facId = opts.facId end
   if opts.page then query.page = opts.page end
   return self:get{ path = '/orgs/' .. org .. '/patients', query = query }
end

M.isRetryable = http.isRetryable
M.oauth = oauth

return M
