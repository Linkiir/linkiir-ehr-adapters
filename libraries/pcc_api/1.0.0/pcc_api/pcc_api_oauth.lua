-- pcc_api_oauth.lua — obtaining a PointClickCare access token.
--
-- PointClickCare offers two grants, and they are not interchangeable: they run
-- on different hosts with different transport requirements. Getting this wrong
-- produces errors that read like server faults, so it is worth stating plainly.
--
--   TWO-LEGGED (client_credentials)     — the default here
--     host      connect2.pointclickcare.com
--     transport mutual TLS REQUIRED; without a client certificate the host
--               answers 400 "No required SSL certificate was sent", and a
--               self-signed one is rejected outright
--     identity  the application. No person signs in, nothing expires in a way
--               that needs a human, so it suits an unattended feed
--     state     none worth keeping. An access token is short-lived and can be
--               re-fetched at will, so this adapter holds it in memory only
--
--   THREE-LEGGED (authorization_code)   — available when asked for
--     host      connect.pointclickcare.com
--     transport ordinary TLS; NO client certificate needed
--     identity  the signing user, so API calls carry that person's privileges
--     state     a refresh token that ROTATES on every use and must be persisted
--               by exactly one writer, or the chain breaks
--
-- Only the two-legged path is wired into this adapter's nodes. Everything the
-- three-legged path needs is implemented and tested here, so enabling it is a
-- configuration change plus somewhere to persist the rotated refresh token —
-- not new protocol work.
local http = require 'pcc_api_http'

local M = {}

local FORM = 'application/x-www-form-urlencoded'

--- Basic base64(clientId:clientSecret), which is how PointClickCare expects the
-- application's identity on the token endpoint.
local function basicAuth(clientId, clientSecret)
   local raw = tostring(clientId or '') .. ':' .. tostring(clientSecret or '')
   return 'Basic ' .. linkiir.codec.base64.encode(raw)
end

local function formEncode(pairsList)
   local out = {}
   for _, kv in ipairs(pairsList) do
      out[#out + 1] = kv[1] .. '=' .. linkiir.codec.uri.encode(tostring(kv[2] or ''))
   end
   return table.concat(out, '&')
end

--- Pull the token fields out of a token-endpoint response.
local function readTokenBody(json)
   if type(json) ~= 'table' or type(json.access_token) ~= 'string' then
      return nil, { kind = 'decode', status = 200,
                    message = 'token response carried no access_token' }
   end
   local ttl = tonumber(json.expires_in) or 3600
   return {
      accessToken  = json.access_token,
      expiresAt    = os.time() + ttl,
      refreshToken = json.refresh_token,
      refreshTtl   = tonumber(json.refresh_token_expires_in),
      -- PointClickCare returns the organization with the token rather than
      -- taking it as input, so it is discovered here rather than configured.
      orgUuid      = (type(json.metadata) == 'table') and json.metadata.orgUuid or nil,
      scope        = json.scope,
   }
end

-- --- two-legged ------------------------------------------------------------

--- Obtain an application access token with the client_credentials grant.
--
-- Requires mutual TLS. The certificate check happens here rather than at the
-- transport layer so the message names the actual problem instead of surfacing
-- as a confusing handshake or 400 from the host.
function M.clientCredentials(conn)
   if not http.hasClientCert(conn) then
      return nil, { kind = 'client', status = 0,
                    message = 'two-legged OAuth requires a client certificate: ' ..
                              'set Client Certificate File and Client Key File' }
   end

   local res, err = http.sendJson{
      method = 'POST',
      url    = conn.authBase .. '/auth/token',
      conn   = conn,
      headers = {
         ['Authorization'] = basicAuth(conn.clientId, conn.clientSecret),
         ['Content-Type']  = FORM,
         ['Accept']        = 'application/json',
      },
      body = formEncode{ { 'grant_type', 'client_credentials' } },
   }
   if not res then return nil, err end
   if res.simulated then
      return { simulated = true, accessToken = '', expiresAt = 0 }
   end
   return readTokenBody(res.json)
end

-- --- three-legged (available on request) -----------------------------------

--- The URL to send an administrator's browser to.
-- Sign-in uses `orgcode.username`, which is the detail that most often trips
-- up a first connection.
function M.authorizeUrl(conn, state)
   return conn.authBase .. '/auth/login'
      .. '?client_id=' .. linkiir.codec.uri.encode(conn.clientId or '')
      .. '&response_type=code'
      .. '&redirect_uri=' .. linkiir.codec.uri.encode(conn.redirectUri or '')
      .. '&state=' .. linkiir.codec.uri.encode(state or '')
end

--- Exchange an authorization code. The code is single-use and expires in about
-- 60 seconds, so a callback must do this inline rather than queueing the work.
function M.exchangeCode(conn, code)
   local res, err = http.sendJson{
      method = 'POST',
      url    = conn.authBase .. '/auth/token',
      conn   = conn,
      headers = {
         ['Authorization'] = basicAuth(conn.clientId, conn.clientSecret),
         ['Content-Type']  = FORM,
         ['Accept']        = 'application/json',
      },
      body = formEncode{
         { 'grant_type',   'authorization_code' },
         { 'code',         code },
         { 'redirect_uri', conn.redirectUri },
      },
   }
   if not res then return nil, err end
   if res.simulated then return { simulated = true } end
   return readTokenBody(res.json)
end

--- Swap a refresh token for a new pair.
--
-- The response carries a NEW refresh token and the old one stops working, so
-- whoever calls this must persist the result before the next attempt. Two
-- components refreshing the same authorization will break each other.
function M.refresh(conn, refreshToken)
   local res, err = http.sendJson{
      method = 'POST',
      url    = conn.authBase .. '/auth/token',
      conn   = conn,
      headers = {
         ['Authorization'] = basicAuth(conn.clientId, conn.clientSecret),
         ['Content-Type']  = FORM,
         ['Accept']        = 'application/json',
      },
      body = formEncode{
         { 'grant_type',    'refresh_token' },
         { 'refresh_token', refreshToken },
      },
   }
   if not res then return nil, err end
   if res.simulated then return { simulated = true } end
   return readTokenBody(res.json)
end

--- Revoke a token. Best effort: a failure here is worth logging, not stopping.
function M.revoke(conn, token, hint)
   return http.send{
      method = 'POST',
      url    = conn.authBase .. '/auth/revoke',
      conn   = conn,
      headers = {
         ['Authorization'] = basicAuth(conn.clientId, conn.clientSecret),
         ['Content-Type']  = FORM,
      },
      body = formEncode{
         { 'token', token },
         { 'token_type_hint', hint or 'refresh_token' },
      },
   }
end

-- --- redirect state --------------------------------------------------------

--- Sign a state value for the authorize redirect.
--
-- Carries a nonce and an expiry only. State crosses an untrusted browser, so it
-- is signed to prove it came from us, and deliberately carries nothing worth
-- reading if it leaks.
function M.signState(key, ttlSeconds)
   local payload = linkiir.json.serialize{
      nonce     = linkiir.sys.guid(128),
      expiresAt = os.time() + (tonumber(ttlSeconds) or 600),
   }
   local sig = linkiir.sec.hmac{ algorithm = 'sha256', key = key,
                                 data = payload, hex = true }
   return linkiir.codec.base64.encode(payload) .. '.' .. sig
end

--- Verify state echoed back by PointClickCare. Returns claims, or nil plus a
-- reason. The signature is checked before the payload is trusted.
function M.verifyState(key, state)
   if type(state) ~= 'string' then return nil, 'missing state' end
   local encoded, sig = state:match('^([^%.]+)%.([0-9a-f]+)$')
   if not encoded then return nil, 'malformed state' end

   local ok, payload = pcall(linkiir.codec.base64.decode, encoded)
   if not ok or type(payload) ~= 'string' or payload == '' then
      return nil, 'malformed state'
   end

   local expect = linkiir.sec.hmac{ algorithm = 'sha256', key = key,
                                    data = payload, hex = true }
   -- Constant-time compare: a mismatch must not reveal where it diverged.
   if #expect ~= #sig then return nil, 'bad signature' end
   local diff = 0
   for i = 1, #expect do
      diff = diff + ((expect:byte(i) == sig:byte(i)) and 0 or 1)
   end
   if diff ~= 0 then return nil, 'bad signature' end

   local parsed, claims = pcall(linkiir.json.parse, payload)
   if not parsed or type(claims) ~= 'table' then return nil, 'malformed state' end
   if type(claims.expiresAt) ~= 'number' or os.time() >= claims.expiresAt then
      return nil, 'state expired'
   end
   return claims
end

return M
