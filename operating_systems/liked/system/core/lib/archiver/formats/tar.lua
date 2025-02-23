local fs = require("filesystem")
local paths = require("paths")
local unicode = require("unicode")

-----------------------------------------------------
--name       : bin/tar.lua
--description: creating, viewing and extracting tar archives on disk and tape
--author     : mpmxyz
--github page: https://github.com/mpmxyz/ocprograms
--forum page : http://oc.cil.li/index.php?/topic/421-tar-for-opencomputers/
-----------------------------------------------------
--[[
  tar archiver for OpenComputers
  for further information check the usage text or man page
  
  TODO: support non primary tape drives
  TODO: detect symbolic link cycles (-> remember already visited, resolved paths)
]]
local BLOCK_SIZE = 512
local NULL_BLOCK = ("\0"):rep(BLOCK_SIZE)

--formats numbers and stringvalues to comply to the tar format
local function formatValue(text, length, maxDigits)
    if type(text) == "number" then
        maxDigits = maxDigits or (length - 1) --that is default
        text = ("%0" .. maxDigits .. "o"):format(text):sub(-maxDigits, -1)
    elseif text == nil then
        text = ""
    end
    return (text .. ("\0"):rep(length - #text)):sub(-length, -1)
end

--a utility to make accessing the header easier
--Only one header is accessed at a time: no need to throw tables around.
local header = {}
--loads a header, uses table.concat on tables, strings are taken directly
function header:init(block)
    if type(block) == "table" then
        --combine tokens to form one 512 byte long header
        block = table.concat(block, "")
    elseif block == nil then
        --make this header a null header
        block = NULL_BLOCK
    end
    if #block < BLOCK_SIZE then
        --add "\0"s to reach 512 bytes
        block = block .. ("\0"):rep(BLOCK_SIZE - #block)
    end
    --remember the current block
    self.block = block
end
--takes the given data and creates a header from it
--the resulting block can be retrieved via header:getBytes()
function header:assemble(data)
    if #data.name > 100 then
        local longName = data.name
        --split at slash
        local minPrefixLength = #longName - 101 --(100x suffix + 1x slash)
        local splittingSlashIndex = longName:find("/", minPrefixLength + 1, true)
        if splittingSlashIndex then
            --can split path in 2 parts separated by a slash
            data.filePrefix = longName:sub(1, splittingSlashIndex - 1)
            data.name = longName:sub(splittingSlashIndex + 1, -1)
        else
            --unable to split path; try to put path to the file prefix
            data.filePrefix = longName
            data.name = ""
        end
        --checking for maximum file prefix length
        assert(#data.filePrefix <= 155, "File name '" .. longName .. "' is too long; unable to apply ustar splitting!")
        --force ustar format
        data.ustarIndicator = "ustar"
        data.ustarVersion = "00"
    end
    local tokens = {
        formatValue(data.name, 100), --1
        formatValue(data.mode, 8), --2
        formatValue(data.owner, 8), --3
        formatValue(data.group, 8), --4
        formatValue(data.size, 12), --5
        formatValue(data.lastModified, 12), --6
        "        ",
         --8 spaces                 --7
        formatValue(data.typeFlag, 1), --8
        formatValue(data.linkName, 100) --9
    }
    --ustar extension?
    if data.ustarIndicator then
        table.insert(tokens, formatValue(data.ustarindicator, 6))
        table.insert(tokens, formatValue(data.ustarversion, 2))
        table.insert(tokens, formatValue(data.ownerUser, 32))
        table.insert(tokens, formatValue(data.ownerGroup, 32))
        table.insert(tokens, formatValue(data.deviceMajor, 8))
        table.insert(tokens, formatValue(data.deviceMinor, 8))
        table.insert(tokens, formatValue(data.filePrefix, 155))
    end
    --temporarily assemble header for checksum calculation
    header:init(tokens)
    --calculating checksum
    tokens[7] = ("%06o\0\0"):format(header:checksum(0, BLOCK_SIZE))
    --assemble final header
    header:init(tokens)
end
--extracts the information from the given header
function header:read()
    local data = {}
    data.name = self:extract(0, 100)
    data.mode = self:extract(100, 8)
    data.owner = self:extractNumber(108, 8)
    data.group = self:extractNumber(116, 8)
    data.size = self:extractNumber(124, 12)
    data.lastModified = self:extractNumber(136, 12)
    data.checksum = self:extractNumber(148, 8)
    data.typeFlag = self:extract(156, 1) or "0"
    data.linkName = self:extract(157, 100)
    data.ustarIndicator = self:extract(257, 6)

    --There is an old format using "ustar  \0" instead of "ustar\0".."00"?
    if data.ustarIndicator and data.ustarIndicator:sub(1, 5) == "ustar" then
        data.ustarVersion = self:extractNumber(263, 2)
        data.ownerUser = self:extract(265, 32)
        data.ownerGroup = self:extract(297, 32)
        data.deviceMajor = self:extractNumber(329, 8)
        data.deviceMinor = self:extractNumber(337, 8)
        data.filePrefix = self:extract(345, 155)
    end

    --assert(self:verify(data.checksum), ERRORS.invalidChecksum)
    --assemble raw file name, normally relative to working dir
    if data.filePrefix then
        data.name = data.filePrefix .. "/" .. data.name
        data.filePrefix = nil
    end
    --assert(data.name, ERRORS.noHeaderName)
    return data
end
--returns the whole 512 bytes of the header
function header:getBytes()
    return header.block
end
--returns if the header is a null header
function header:isNull()
    return self.block == NULL_BLOCK
end
--extracts a 0 terminated string from the given area
function header:extract(offset, size)
    --extract size bytes from the given offset, strips every NULL character
    --returns a string
    return self.block:sub(1 + offset, size + offset):match("[^\0]+")
end
--extracts an octal number from the given area
function header:extractNumber(offset, size)
    --extract size bytes from the given offset
    --returns the first series of octal digits converted to a number
    return tonumber(self.block:sub(1 + offset, size + offset):match("[0-7]+") or "", 8)
end
--calculates the checksum for the given area
function header:checksum(offset, size, signed)
    --calculates the checksum of a given range
    local sum = 0
    --summarize byte for byte
    for index = 1 + offset, size + offset do
        if signed then
            --interpretation of a signed byte: compatibility for bugged implementations
            sum = sum + (self.block:byte(index) + 128) % 256 - 128
        else
            sum = sum + self.block:byte(index)
        end
    end
    --modulo to take care of negative sums
    --The whole reason for the signed addition is that some implementations
    --used signed bytes instead of unsigned ones and therefore computed 'wrong' checksums.
    return sum % 0x40000
end
--checks if the given checksum is valid for the loaded header
function header:verify(checksum)
    local checkedSums = {
        [self:checksum(0, 148, false) + 256 + self:checksum(156, 356, false)] = true,
        [self:checksum(0, 148, true) + 256 + self:checksum(156, 356, true)] = true
    }
    return checkedSums[checksum] or false
end

local function tarFiles(files, ignoredObjects, isDirectoryContent, dir, outputFile)
    --combines files[2], files[3], ... into files[1]
    --prepare output stream
    local target, closeAtExit
    if type(files[1]) == "string" then
        local targetFile = files[1]
        ignoredObjects[targetFile] = ignoredObjects[targetFile] or true
        target = assert(fs.open(targetFile, "wb"))
        closeAtExit = true
    else
        target = files[1]
        closeAtExit = false
    end

    for i = 2, #files do
        local file = files[i]
        if not paths.equals(file, outputFile) then
            local objectType

            if fs.isDirectory(file) then
                objectType = "dir" --It's a directory.
            else
                objectType = "file" --It's a normal file.
            end

            if objectType == "dir" and ignoredObjects[file] ~= "strict" then
                local list = {target}
                local i = 2
                for _, containedFile in ipairs(fs.list(file)) do
                    list[i] = paths.concat(file, containedFile)
                    i = i + 1
                end
                tarFiles(list, ignoredObjects, true, dir, outputFile)
            end
            --Ignored objects are not added to the tar.
            if not ignoredObjects[file] then
                local data = {}
                --get relative path to current directory
                data.name = file:sub(#dir + 2, #file)
                --add object specific data

                data.lastModified = math.floor(fs.lastModified(file) / 1000) --Java returns milliseconds...
                if objectType == "dir" then
                    --It's a directory.
                    data.typeFlag = "5"
                    data.mode = 448 --> 700 in octal -> rwx------
                elseif objectType == "file" then
                    --It's a normal file.
                    data.typeFlag = "0"
                    data.size = fs.size(file)
                    data.mode = 384 --> 600 in octal -> rw-------
                end

                --assemble header
                header:assemble(data)
                --write header
                assert(target.write(header:getBytes()))
                --copy file contents
                if objectType == "file" then
                    --open source file
                    local source = assert(fs.open(file, "rb"))
                    --keep track of what has to be copied
                    local bytesToCopy = data.size
                    --copy file contents
                    local function iterator()
                        local str = source.read(BLOCK_SIZE)
                        if str ~= "" then
                            return str
                        end
                    end
                    for block in iterator do
                        assert(target.write(block))
                        bytesToCopy = bytesToCopy - #block
                        assert(bytesToCopy >= 0, "Error: File grew while copying! Is it the output file?")

                        if #block < BLOCK_SIZE then
                            assert(target.write(("\0"):rep(BLOCK_SIZE - #block)))
                            break
                        end
                    end
                    --close source file
                    source:close()

                    assert(bytesToCopy <= 0, "Error: Could not copy file!")
                end
            end
        end
    end
    if not isDirectoryContent then
        assert(target.write(NULL_BLOCK)) --Why wasting 0.5 KiB if you can waste a full KiB? xD
        assert(target.write(NULL_BLOCK)) --(But that's the standard!)
    end
    if closeAtExit then
        target:close()
    end
end

local extractingExtractors = {
    ["0"] = function(data, options) --file
        local dir = paths.path(data.file)
        if not fs.exists(dir) then
            fs.makeDirectory(dir)
        end

        local target = assert(fs.open(data.file, "wb"))
        local bytesToCopy = data.size

        local function extractor(block)
            if block == nil then
                target:close()
                return nil
            end
            if #block > bytesToCopy then
                block = block:sub(1, bytesToCopy)
            end
            assert(target.write(block))
            bytesToCopy = bytesToCopy - #block
            if bytesToCopy <= 0 then
                target:close()
                return nil
            else
                return extractor
            end
        end

        if bytesToCopy > 0 then
            return extractor
        else
            target:close()
        end
    end,
    ["2"] = function(data, options) --symlink
    end,
    ["5"] = function(data, options) --directory
        if not fs.isDirectory(data.file) then
            fs.makeDirectory(data.file)
        end
    end
}

local function untarFiles(file, dir, extractorList)
    --prepare input stream
    local source = assert(fs.open(file, "rb"))
    local extractor = nil
    local hasDoubleNull = false
    local function iterator()
        local str = source.read(BLOCK_SIZE)
        if str ~= "" then
            return str
        end
    end
    for block in iterator do
        if #block < BLOCK_SIZE then
            error("Error: Unfinished Block; missing " .. (BLOCK_SIZE - #block) .. " bytes!")
        end
        if extractor == nil then
            --load header
            header:init(block)
            if header:isNull() then
                --check for second null block
                if source.read(BLOCK_SIZE) == NULL_BLOCK then
                    hasDoubleNull = true
                end
                --exit/close file when there is a NULL header
                break
            else
                --read block as header
                local data = header:read()
                --enforcing relative paths
                data.file = paths.concat(dir, data.name)
                --get extractor
                local extractorInit = extractorList[data.typeFlag]
                assert(extractorInit, 'Unknown type flag "' .. tostring(data.typeFlag) .. '"')
                extractor = extractorInit(data)
            end
        else
            extractor = extractor(block)
        end
        if type(extractor) == "number" then
            if extractor > 0 then
                --adjust extractorInit to block size
                local bytesToSkip = math.ceil(extractor / BLOCK_SIZE) * BLOCK_SIZE
                --skip (extractorInit) bytes
                assert(source:seek("cur", bytesToSkip))
            end
            --expect next header
            extractor = nil
        end
    end
    assert(extractor == nil, "Error: Reached end of file but expecting more data!")
    source:close()
end

--------------------------------------------

local tar = {}

function tar.pack(dir, outputpath)
	dir = paths.canonical(dir)
	outputpath = paths.canonical(outputpath)
	return pcall(tarFiles, {outputpath, dir}, {}, nil, dir, outputpath)
end

function tar.unpack(inputpath, dir)
	inputpath = paths.canonical(inputpath)
	dir = paths.canonical(dir)
	return pcall(untarFiles, inputpath, dir, extractingExtractors)
end

tar.unloadable = true
return tar