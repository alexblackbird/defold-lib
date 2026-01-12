local M = {}

local unicode = require "modules.arabic.unicode"
local rev = require "modules.arabic.reverse"

local format = string.format
local byte = string.byte
local char = string.char

local function toHex(str)
    return (str:gsub('.', function(c)
        return format('%02X', byte(c))
    end))
end

local function fromHex(str)
    return (str:gsub('..', function(cc)
        return char(tonumber(cc, 16))
    end))
end

local non_arabic_alphabet_and_digits = {
    -- Строчные буквы
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
    "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",

    -- Прописные буквы
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",

    -- Цифры
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    
    -- Знаки препинания
    ".", ",", "!", "?", ":", ";", "-", "_",

    -- Кавычки
    "'", "`",

    -- Скобки
    "(", ")", "[", "]", "{", "}",

    -- Слеши
    "/", " ",

    -- Знаки математических операций
    "+", "-", "*", "/", "%", "^",

    -- Прочее
    "=", "&", "|", "@", "#", "$", "%", "^", "*", "(", ")", "<", ">",

    -- Специальные символы
    "€", "£", "¥", "©", "®", "™",
}

local function isNonArabicChar(c)
    for _, char in ipairs(non_arabic_alphabet_and_digits) do
        if c == char then
            return true
        end
    end
    return false
end

function M.convert(str)
    local letters = {}
    local k = 1
    for c in string.gmatch(str, "[%z\1-\127\194-\244][\128-\191]*") do
        letters[k] = tostring(string.lower(toHex(c)))
        k = k + 1
    end
    
    local hex = ""
    
    for k, l in pairs(letters) do        
        for u in pairs(unicode.hex) do
            if tostring(u) == l then
                
                if fromHex(l) == "ل" then

                    if letters[k+1] and fromHex(letters[k+1]) == "ا" then -- это обычный алеф
                        letters[k] = "efbbbb"
                        
                        table.remove(letters, k+1)
                        l = letters[k]
                        u = letters[k]
                    end

                    if letters[k+1] and fromHex(letters[k+1]) == "آ" then -- это альфа мида
                        letters[k] = "efbbb5"

                        table.remove(letters, k+1)
                        l = letters[k]
                        u = letters[k]
                    end

                    if letters[k+1] and fromHex(letters[k+1]) == "إ" then -- альиф хамза с фатха
                        letters[k] = "efbbb9"

                        table.remove(letters, k+1)
                        l = letters[k]
                        u = letters[k]
                    end

                    if letters[k+1] and fromHex(letters[k+1]) == "ٱ" then -- альиф хамза с фатха
                        letters[k] = "efbbb7"

                        table.remove(letters, k+1)
                        l = letters[k]
                        u = letters[k]
                    end
                end
                
                if k == 1 or letters[k - 1] == unicode.space then
                    letters[k] = unicode.hex[u]["first"]
                elseif letters[k + 1] ~= unicode.space and letters[k - 1] ~= unicode.space and letters[k + 1] ~= nil then
                    letters[k] = unicode.hex[u]["middle"]
                elseif letters[k + 1] == unicode.space or letters[k + 1] == nil then
                    letters[k] = unicode.hex[u]["last"]
                end
                
                for _, s in pairs(unicode.symbols) do
                    if letters[k - 1] == s and letters[k + 1] ~= s then
                        letters[k] = unicode.hex[u]["first"]
                    elseif letters[k - 1] == s and letters[k + 1] == s then
                        letters[k] = unicode.hex[u]["isolated"]
                    elseif k ~= 1 and letters[k + 1] == s and letters[k - 1] ~= s then
                        
                        letters[k] = unicode.hex[u]["last"]
                        
                        -- часности
                        if fromHex(l) == "ة" and fromHex(letters[k - 1]) == "ء" then
                            letters[k] = unicode.hex[u]["isolated"]
                        end
                    elseif letters[k + 1] == "d88c" or letters[k + 1] == "d89f" then -- арабская запятая или вопрос
                        letters[k] = unicode.hex[u]["last"]
                    end
                end
                
                for _, b in pairs(unicode.breakWord) do
                    if letters[k - 1] == b and letters[k + 1] ~= unicode.space and letters[k + 1] ~= nil then
                        
                        if letters[k + 1] == "d88c" then
                            letters[k] = unicode.hex[u]["isolated"]
                        else
                            letters[k] = unicode.hex[u]["first"]
                        end
                        
                    elseif letters[k - 1] == b and letters[k + 1] == b or letters[k - 1] == b and letters[k + 1] == unicode.space then
                        letters[k] = unicode.hex[u]["last"]
                    elseif letters[k - 1] == b and letters[k + 1] == b then
                        letters[k] = unicode.hex[u]["isolated"]
                    elseif letters[k - 1] == b and letters[k + 1] == nil then
                        letters[k] = unicode.hex[u]["isolated"]
                    elseif letters[k - 1] == b and letters[k + 1] == unicode.space then
                        letters[k] = unicode.hex[u]["isolated"]
                    end
                end
                
            end
        end
    end
    
    local hex_table = {}
    local current_non_arabic_letter = nil -- запоминаем что это не арабский символ
    
    for i, l in pairs(letters) do        
        if isNonArabicChar(fromHex(l)) then
            if not current_non_arabic_letter then
                table.insert(hex_table, l)
                
                -- просто запоминаем что был не арабский символ
                current_non_arabic_letter = #hex_table
            else
                -- это не арабский символ и до этого был не арабский символ
                table.insert(hex_table, current_non_arabic_letter, l)
            end
        else
            -- просто запоминаем что был арабский символ - сбросить маячок
            current_non_arabic_letter = nil
            
            table.insert(hex_table, l)
        end
    end

    hex = table.concat(hex_table, "")
    
    -- reset letters not needed as it is local now
    local Text = rev.utf8reverse(fromHex(tostring(hex)))

    return Text
end

return M
