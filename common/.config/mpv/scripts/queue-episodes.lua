local utils = require 'mp.utils'

local function queue_subsequent_episodes()
    if mp.get_property_number("playlist-count", 1) > 1 then
        return
    end

    local path = mp.get_property("path")
    if not path or path:find("^%a+://") then
        return
    end

    local dir, filename = utils.split_path(path)
    if not dir or not filename then
        return
    end

    local prefix, cur_str, ext = filename:match("^(.*%D)(%d+)(%.[^.]+)$")
    if not prefix or not cur_str or not ext then
        return
    end

    local cur_num = tonumber(cur_str)
    local files = utils.readdir(dir, "files")
    if not files then
        return
    end

    local matches = {}
    for _, file in ipairs(files) do
        local file_prefix, num_str, file_ext = file:match("^(.*%D)(%d+)(%.[^.]+)$")
        if file_prefix == prefix and file_ext == ext then
            local num = tonumber(num_str)
            if num and num > cur_num then
                table.insert(matches, {name = file, num = num})
            end
        end
    end

    table.sort(matches, function(a, b)
        return a.num < b.num
    end)

    for _, item in ipairs(matches) do
        local file_path = utils.join_path(dir, item.name)
        mp.commandv("loadfile", file_path, "append")
    end
end

mp.register_event("file-loaded", queue_subsequent_episodes)
