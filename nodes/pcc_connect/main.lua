-- PCC Connect — Source Custom, on a timer
--
-- Proves the PointClickCare connection works and reports what it can see.
--
-- With two-legged OAuth this is genuinely all there is: the application
-- authenticates itself, so there is no person to sign in, no refresh token to
-- keep, and nothing to persist. The token is short-lived and re-obtainable at
-- any moment, so it lives in memory for the life of the VM and is simply fetched
-- again when it ages out. That is why this adapter has no database.
--
-- Each cycle it obtains a token if needed, reads the organization's facilities
-- as a liveness check, and pushes a small status message downstream. The
-- facilities call is chosen on purpose: it is the cheapest request that proves
-- the token, the organization and the mutual-TLS transport are all correct, and
-- it yields the facId values the API expects. The number shown in the
-- PointClickCare UI is usually the facility *code*, not that facId, which is a
-- reliable source of confusion when wiring up a first integration.
local PCC    = require 'pcc_api'
local PCCcfg = require 'pcc_api_config'

function main()
   local client, cfg = PCCcfg.fromNodeConfig()

   local gaps = PCCcfg.missing(cfg)
   if gaps then
      -- A freshly imported adapter has no credentials. Normal, not an error.
      linkiir.log.info('PCC Connect: not configured yet (' .. gaps .. ')')
      return
   end

   local tok, err = client:connect()
   if not tok then
      if PCC.isRetryable(err) then
         -- Raise so the runtime backs off rather than hammering the token endpoint.
         error('PCC Connect: ' .. err.message)
      end
      -- A configuration or privilege problem will not fix itself by retrying.
      linkiir.log.warn('PCC Connect: ' .. err.message)
      return
   end
   if tok.simulated then
      linkiir.log.info('PCC Connect: Live Mode is off, no token requested. ' ..
                       client:describe())
      return
   end

   local facilities, ferr = client:facilities()
   if not facilities then
      -- The token worked but the first call did not. Report it and keep the
      -- token: the next cycle may well succeed.
      linkiir.log.warn('PCC Connect: authenticated, but reading facilities failed: '
                       .. ferr.message)
      linkiir.flow.push{
         data = linkiir.json.serialize{
            type          = 'PCC_CONNECTION',
            correlationId = linkiir.sys.guid(128),
            createdAt     = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            mode          = PCCcfg.mode(cfg),
            connected     = true,
            orgUuid       = client:orgUuid(),
            describe      = client:describe(),
            warning       = ferr.message,
         },
      }
      return
   end

   local list = (facilities.json or {}).data or (facilities.json or {}).facilities or {}
   local summary = {}
   for _, f in ipairs(list) do
      summary[#summary + 1] = {
         facId        = f.facId,
         facilityCode = f.facilityCode,
         facilityName = f.facilityName or f.name,
      }
   end

   linkiir.log.info(string.format('PCC Connect: %s · %d facility(ies)',
      client:describe(), #summary))

   linkiir.flow.push{
      data = linkiir.json.serialize{
         type          = 'PCC_CONNECTION',
         correlationId = linkiir.sys.guid(128),
         createdAt     = os.date('!%Y-%m-%dT%H:%M:%SZ'),
         mode          = PCCcfg.mode(cfg),
         connected     = true,
         orgUuid       = client:orgUuid(),
         describe      = client:describe(),
         facilityCount = #summary,
         facilities    = summary,
      },
   }
end
