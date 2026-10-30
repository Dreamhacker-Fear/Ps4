return function(S, ctx)
    local HttpService = game:GetService("HttpService")
    local canWrite = function()
        return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
    end

    S.LIB_FILE = "ps4_library.json"
    S.SETTINGS_FILE = "ps4_settings.json"

    S.library = {}
    S.earned = S.earned or {}

    function S.loadLibrary()
        if not canWrite() then return end
        if isfile(S.LIB_FILE) then
            local ok, data = pcall(function()
                return HttpService:JSONDecode(readfile(S.LIB_FILE))
            end)
            if ok and type(data) == "table" then
                S.library = data
            end
        end
    end

    function S.saveLibrary()
        if not canWrite() then return end
        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(S.library)
        end)
        if ok then writefile(S.LIB_FILE, encoded) end
    end

    function S.sortedLibrary()
        local list = {}
        for id, entry in pairs(S.library) do table.insert(list, { id = id, entry = entry }) end
        table.sort(list, function(a, b)
            local ta, tb = a.entry.downloadedAt or 0, b.entry.downloadedAt or 0
            if ta ~= tb then return ta < tb end
            return a.id < b.id
        end)
        return list
    end

    function S.libraryCount()
        local n = 0
        for _ in pairs(S.library) do n += 1 end
        return n
    end

    function S.isDownloaded(id)
        return S.library[tostring(id)] ~= nil
    end

    function S.deleteFromLibrary(id)
        if not S.library[id] then return false end
        S.library[id] = nil
        S.saveLibrary()
        S.notify("Deleted")
        if S.refreshLocal then S.refreshLocal() end
        return true
    end

    function S.saveSettings()
        if not canWrite() then return end
        pcall(function()
            writefile(S.SETTINGS_FILE, HttpService:JSONEncode({ settings = S.settings, earned = S.earned }))
        end)
    end

    function S.loadSettings()
        if not canWrite() then return end
        if not isfile(S.SETTINGS_FILE) then return end
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(S.SETTINGS_FILE)) end)
        if ok and type(data) == "table" then
            for k, v in pairs(data.settings or {}) do S.settings[k] = v end
            if type(data.earned) == "table" then S.earned = data.earned end
        end
    end

    S.loadLibrary(); S.loadSettings()
    return S
end
