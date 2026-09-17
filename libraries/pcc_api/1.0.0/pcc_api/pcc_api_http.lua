-- pcc_api_http.lua — one place where every PointClickCare request is actually
-- sent, so retry policy, mutual TLS and simulation behave identically for the
-- token exchange and for API calls.
--
-- Nothing here raises. Each function returns result or nil, err where err is a
-- table { kind, status, message }. `kind` is what a node branches on:
--
--   'transport'   the request never got an answer
--   'auth'        401/403 — the token is stale, or the caller lacks the scope
--   'ratelimit'   429 — back off and retry later
--   'server'      5xx — PointClickCare's problem, retry later
--   'client'      other 4xx — a bad request, retrying will not help
--   'decode'      a 2xx body that is not the JSON we expected
--
-- Splitting 'auth' out matters: it is the only failure a caller can fix by
-- getting a fresh token, and a two-legged client can always get one.
local M = {}

M.RETRYABLE = { transport = true, ratelimit = true, server = true }

--- True when this failure is worth trying again on a later cycle.
function M.isRetryable(err)
   return err ~= nil and M.RETRYABLE[err.kind] == true
end

local function classify(status)
   if status == 401 or status == 403 then return 'auth' end
   if status == 429 then return 'ratelimit' end
   if status >= 500 then return 'server' end
   if status >= 400 then return 'client' end
   return nil
end

--- Build the tls sub-table for linkiir.link.web.
--
-- Returned only when a certificate and key are both configured. The runtime
-- rejects one without the other, and two-legged PointClickCare requires mutual
-- TLS, so this is the difference between a working adapter and a handshake
-- error that reads like a server fault.
function M.tlsOptions(conn)
   if conn.certFile == nil or conn.certFile == '' then return nil end
   if conn.keyFile == nil or conn.keyFile == '' then return nil end
   local tls = { certFile = conn.certFile, keyFile = conn.keyFile }
   if conn.caFile ~= nil and conn.caFile ~= '' then tls.caFile = conn.caFile end
   return tls
end

--- True when mutual TLS is configured. Two-legged needs it; three-legged does
-- not, and the two modes even live on different PointClickCare hosts.
function M.hasClientCert(conn)
   return M.tlsOptions(conn) ~= nil
end

--- Send one request and classify the outcome.
--
-- opts: { method, url, headers, body, conn }
-- conn supplies timeout, verifyTls, live and the mutual-TLS paths.
function M.send(opts)
   local conn = opts.conn or {}
   local method = string.upper(opts.method or 'GET')

   local args = {
      url       = opts.url,
      headers   = opts.headers or {},
      timeout   = tonumber(conn.timeout) or 20,
      verifyTls = conn.verifyTls ~= false,
      live      = conn.live ~= false,
   }
   if opts.body ~= nil then args.body = opts.body end
   local tls = M.tlsOptions(conn)
   if tls then args.tls = tls end

   local fn = (method == 'POST') and linkiir.link.web.post or linkiir.link.web.get
   local resp, err = fn(args)

   if not resp then
      return nil, { kind = 'transport', status = 0,
                    message = 'no response from PointClickCare (' ..
                              tostring(err and err.code or 'unknown') .. ')' }
   end

   -- Live Mode off: the runtime returns a simulated envelope and performs no
   -- I/O. Surfaced explicitly so a node can report "configured but not sent"
   -- rather than mistaking an empty body for a real answer.
   if resp.simulated then
      return { simulated = true, status = 0, body = '', json = nil }
   end

   local kind = classify(tonumber(resp.code) or 0)
   if kind then
      return nil, { kind = kind, status = resp.code,
                    message = 'PointClickCare returned HTTP ' .. tostring(resp.code) }
   end

   return { status = resp.code, body = resp.body or '', headers = resp.headers }
end

--- Send a request and decode a JSON body.
function M.sendJson(opts)
   local res, err = M.send(opts)
   if not res then return nil, err end
   if res.simulated then return res end

   if res.body == '' then
      -- A 204 or an empty 200 is a legitimate answer to a write.
      res.json = nil
      return res
   end

   local ok, decoded = pcall(linkiir.json.parse, res.body)
   if not ok or type(decoded) ~= 'table' then
      return nil, { kind = 'decode', status = res.status,
                    message = 'response body was not JSON' }
   end
   res.json = decoded
   return res
end

return M
