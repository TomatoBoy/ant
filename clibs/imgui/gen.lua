local meta; do
    local json = dofile "3rd/ant/pkg/ant.json/main.lua"
    local function readall(path)
        local f <close> = assert(io.open(path, "rb"))
        return f:read "a"
    end
    meta = json.decode(readall "3rd/ant/clibs/imgui/dear_bindings/cimgui.json")
end

local w <close> = assert(io.open("3rd/ant/clibs/imgui/imgui_enum.h", "wb"))

local function writeln(fmt, ...)
    w:write(string.format(fmt, ...))
    w:write "\n"
end

local disable <const> = {
    ImGuiTabItemFlags = true,
    ImGuiDataType = true,
    ImGuiDir = true,
    ImGuiNavInput = true,
    ImGuiBackendFlags = true,
    ImGuiButtonFlags = true,
    ImGuiMouseSource = true,
    ImGuiCond = true,
    ImDrawFlags = true,
    ImDrawListFlags = true,
    ImFontAtlasFlags = true,
    ImGuiViewportFlags = true,
    ImGuiModFlags = true,
}

local init = {
    flags = {},
    enums = {},
}

local new_enums = {}
for _, enums in ipairs(meta.enums) do
    if enums.conditionals then
        goto continue
    end
    local realname = enums.name:match "(.-)_?$"
    if disable[realname] then
        writeln("//%s", realname)
        writeln("")
        goto continue
    end
    local name = realname:match "^ImGui(%a+)$" or realname:match "^Im(%a+)$"
    if enums.is_flags_enum then
        table.insert(init.flags, name)
    else
        table.insert(init.enums, name)
    end
    writeln("static struct enum_pair e%s[] = {", name)
    for _, enum in ipairs(enums.elements) do
        if not enum.is_internal and not enum.conditionals then
            local enum_type, enum_name = enum.name:match "^(%w+)_(%w+)$"
            if enum_type == realname then
                writeln("\tENUM(%s, %s),", enum_type, enum_name)
            else
                local t = new_enums[enum_type]
                if t then
                    t[#t+1] = enum_name
                else
                    new_enums[enum_type] = { enum_name }
                end
            end
        end
    end
    writeln("\t{ NULL, 0 },")
    writeln("};")
    writeln("")
    ::continue::
end

for enum_type, enum_names in pairs(new_enums) do
    local name = enum_type:match "^ImGui(%a+)$" or enum_type:match "^Im(%a+)$"
    table.insert(init.enums, name)
    writeln("static struct enum_pair e%s[] = {", name)
    for _, enum_name in ipairs(enum_names) do
        writeln("\tENUM(%s, %s),", enum_type, enum_name)
    end
    writeln("\t{ NULL, 0 },")
    writeln("};")
    writeln("")
end

writeln("void imgui_enum_init(lua_State* L) {")
writeln("\tlua_newtable(L);")
for _, name in ipairs(init.flags) do
    writeln("\tflag_gen(L, \"%s\", e%s);", name:match "^(.-)Flags$", name)
end
writeln("\tlua_setfield(L, -2, \"flags\");")
writeln("")
writeln("\tlua_newtable(L);")
for _, name in ipairs(init.enums) do
    writeln("\tenum_gen(L, \"%s\", e%s);", name, name)
end
writeln("\tlua_setfield(L, -2, \"enum\");")
writeln("}")
