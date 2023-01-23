local unpack = table.unpack
local format = string.format
local layout = pandoc.layout
local literal, empty, cr, concat, blankline, chomp, space, cblock, rblock, prefixed, nest, hang, nowrap = layout.literal
    , layout.empty, layout.cr, layout.concat, layout.blankline
    , layout.chomp, layout.space, layout.cblock, layout.rblock
    , layout.prefixed, layout.nest, layout.hang, layout.nowrap

Blocks = {}
Blocks.mt = {}
Blocks.mt.__index = function(tbl, key)
    return function() io.stderr:write("Unimplemented " .. key .. "\n") end
end
setmetatable(Blocks, Blocks.mt)

Inlines = {}
Inlines.mt = {}
Inlines.mt.__index = function(tbl, key)
    return function() io.stderr:write("Unimplemented " .. key .. "\n") end
end
setmetatable(Inlines, Inlines.mt)

local function inlines(ils)
    local buff = {}
    for i = 1, #ils do
        local el = ils[i]
        buff[#buff + 1] = Inlines[el.tag](el)
    end
    return concat(buff)
end

local function blocks(bs, sep)
    local dbuff = {}
    for i = 1, #bs do
        local el = bs[i]
        dbuff[#dbuff + 1] = Blocks[el.tag](el)
    end
    return concat(dbuff, sep)
end

Blocks.Para = function(el)
    return inlines(el.content)
end

Blocks.Plain = function(el)
    return inlines(el.content)
end

Blocks.BlockQuote = function(el)
    return concat({
        "[QUOTE]"
        , blocks(el.content)
        , "[/QUOTE]"
    })
end

Blocks.Header = function(el)
    local level = math.min(el.level, 3)
    local result = {
        "[HEADING=" .. level .. "]"
        , inlines(el.content)
        , "[/HEADING]"
    }
    return concat(result)
end

Blocks.Null = function(el)
    return empty
end

Blocks.Table = function(el)
    local tbl = pandoc.utils.to_simple_table(el)
    local result = { "[TABLE]" }

    local rowIndent = "  "
    local cellIndent = "    "

    local hdrcells = {}
    for idx = 1, #tbl.headers do
        local cell = tbl.headers[idx]
        hdrcells[#hdrcells + 1] = blocks(cell, blankline)
    end
    if #hdrcells > 0 then
        result[#result + 1] = rowIndent .. "[TR]"
        for idx = 1, #hdrcells do
            result[#result + 1] = concat({
                cellIndent .. "[TH]"
                , hdrcells[idx]
                , "[/TH]"
            })
        end
        result[#result + 1] = rowIndent .. "[/TR]"
    end

    for rowIdx = 1, #tbl.rows do
        local row = tbl.rows[rowIdx]
        result[#result + 1] = rowIndent .. "[TR]"
        for cellIdx = 1, #row do
            local cell = blocks(row[cellIdx], blankline)
            result[#result + 1] = concat({
                cellIndent .. "[TD]"
                , cell
                , "[/TD]"
            })
        end
        result[#result + 1] = rowIndent .. "[/TR]"
    end

    result[#result + 1] = "[/TABLE]"
    return concat(result, cr)
end

Blocks.BulletList = function(el)
    local result = { "[LIST]" }
    for i = 1, #el.content do
        local content = blocks(el.content[i], blankline)
        result[#result + 1] = concat({
            "[*]"
            , content
        })
    end
    result[#result + 1] = "[/LIST]"
    return concat(result, cr)
end

Blocks.OrderedList = function(el)
    local result = {
        "[LIST=1]"
    }
    for i = 1, #el.content do
        local content = blocks(el.content[i], blankline)
        result[#result + 1] = concat({
            "[*]"
            , content
        })
    end
    result[#result + 1] = "[/LIST]"
    return concat(result, cr)
end

Blocks.CodeBlock = function(el)
    -- , CodeBlock ( "" , [ "php" ] , [] ) "echo $hello . 'world';"
    local result = empty
    local lang = empty
    if #el.classes > 0 then
        lang = el.classes[1]
        table.remove(el.classes, 1)
    end
    if string.lower(lang) == "spoiler" then
        local doc = pandoc.read(el.text)
        result = {
            '[SPOILER]'
            , cr
            , blocks(doc.blocks, blankline)
            , cr
            , "[/SPOILER]"
        }
    elseif string.lower(lang) == "private" then
        local doc = pandoc.read(el.text)
        result = {
            '[PRIVATE]'
            , cr
            , blocks(doc.blocks, blankline)
            , cr
            , "[/PRIVATE]"
        }
    else
        result = {
            '[CODE="'
            , lang
            , '"]'
            , cr
            , el.text
            , cr
            , "[/CODE]"
        }
    end
    return concat(result)
end

Blocks.HorizontalRule = function(el)
    return concat({ "[HR][/HR]", cr })
end

Inlines.Str = function(el)
    return el.text
end

Inlines.Space = function(el)
    return space
end

Inlines.Code = function(el)
    return concat({
        "[ICODE]"
        , el.text
        , "[/ICODE]"
    })
end

Inlines.Emph = function(el)
    return concat({
        "[I]"
        , inlines(el.content)
        , "[/I]"
    })
end

Inlines.Strong = function(el)
    return concat({
        "[B]"
        , inlines(el.content)
        , "[/B]"
    })
end

Inlines.Strikeout = function(el)
    return concat({
        "[S]"
        , inlines(el.content)
        , "[/S]"
    })
end

Inlines.Underline = function(el)
    return concat({
        "[U]"
        , inlines(el.content)
        , "[/U]"
    })
end

Inlines.Link = function(el)
    return concat({
        '[URL="'
        , el.target
        , '"]'
        , inlines(el.content)
        , "[/URL]"
    })
end

Inlines.Quoted = function(el)
    if el.quotetype == "DoubleQuote" then
        return concat { '"', inlines(el.content), '"' }
    else
        return concat { "'", inlines(el.content), "'" }
    end
end

function Writer(doc, opts)
    local d = blocks(doc.blocks, blankline)
    d = nowrap(d)
    return layout.render(concat({ d }))
end
