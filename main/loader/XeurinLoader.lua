--[[ XEURIN PRO | SILENT BOOTSTRAPPER v5.1
     Triple-mirror, validated, resilient bootstrap loader.
     Users execute this file — it fetches the protected engine.
     Anti-tamper: rejects payloads that fail signature or size checks.
     FIX BUG 6: récursion → boucle while (0 stack overflow risk)
--]]

-- ── Configuration ────────────────────────────────────────────────────────────
local MIRRORS = {
    -- Primary: GitHub raw
    (function()
        local p = {
            "https://raw.git","husercontent",".com/",
            "Owner19741/Xeurin/refs/heads/main/main/XeurinObf.lua"
        }
        return table.concat(p)
    end)(),

    -- Fallback 1: jsDelivr CDN (global edge cache)
    (function()
        local p = {
            "https://cdn.jsdelivr.net/gh/",
            "Owner19741/Xeurin@main/main/XeurinObf.lua"
        }
        return table.concat(p)
    end)(),

    -- Fallback 2: GitLab raw (independent CDN)
    (function()
        local p = {
            "https://gitlab.com/xeurin-dist/",
            "main/-/raw/main/XeurinObf.lua"
        }
        return table.concat(p)
    end)(),
}

local MAX_RETRIES    = 9        -- Total attempts across all mirrors
local BASE_DELAY     = 1.0      -- Base backoff seconds
local MAX_DELAY      = 30.0     -- Cap on backoff
local MIN_PAYLOAD    = 1000     -- Bytes — rejects suspiciously small responses
local EXPECTED_SIGN  = "--[["   -- First 4 chars of a valid obfuscated payload

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function getMirror(attempt)
    return MIRRORS[((attempt - 1) % #MIRRORS) + 1]
end

local function isValidPayload(s)
    if type(s) ~= "string"             then return false, "not a string" end
    if #s < MIN_PAYLOAD                then return false, "payload too small (" .. #s .. " bytes)" end
    if s:sub(1, 4) ~= EXPECTED_SIGN   then return false, "bad signature" end
    return true, "ok"
end

local function backoff(attempt)
    return math.min(BASE_DELAY * attempt, MAX_DELAY)
end

-- ── Boot ──────────────────────────────────────────────────────────────────────
-- FIX BUG 6: boucle itérative au lieu de récursion — zéro risque de stack overflow
local function boot()
    local attempt = 1
    while attempt <= MAX_RETRIES do
        local mirror = getMirror(attempt)

        local ok, payload = pcall(function()
            return game:HttpGetAsync(mirror)
        end)

        if not ok then
            -- Erreur réseau → backoff et retry
            task.wait(backoff(attempt))
            attempt = attempt + 1
            continue
        end

        local valid, reason = isValidPayload(payload)
        if not valid then
            -- Payload invalide → backoff et retry
            task.wait(backoff(attempt))
            attempt = attempt + 1
            continue
        end

        -- Payload valid — tenter l'exécution
        local fn, parseErr = loadstring(payload)
        if not fn then
            -- Erreur de parse = payload corrompu, mirror suivant immédiatement
            task.wait(BASE_DELAY)
            attempt = attempt + 1
            continue
        end

        -- Succès — lancer le moteur
        task.spawn(fn)
        return -- sortir de la boucle
    end

    -- Tous les mirrors ont échoué
    warn("[XEURIN] All " .. #MIRRORS .. " mirrors failed after " .. MAX_RETRIES .. " attempts.")
    warn("[XEURIN] Check your internet connection or contact support: dsc.gg/xeurin")
end

task.spawn(boot)
