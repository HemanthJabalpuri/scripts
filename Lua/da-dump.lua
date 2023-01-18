#!/usr/bin/env lua
-- Dumps list of chipsets supported in a MTK DA file
-- Ref:
--  https://github.com/xloem/backyard_mediatek_flasher/blob/2ebc4a33eaba85a69925f69f95b698ca265498ca/parse_da.py
--  https://github.com/RayMarmAung/mtk_da_utils/blob/main/mtk_da_utils/mtk_da_utils.cpp
--  https://github.com/mtek-hack-hack/mtk-open-tools/blob/master/da-dump.py
--  https://github.com/bkerler/mtkclient/blob/1.52/mtkclient/Library/daconfig.py

function getString(n)
  local dat = f:read(n)
  return dat:gsub("\x00", "")
end

function b2hex(dat)
  return (dat:gsub('.', function (c) return string.format('%02X', c:byte()) end))
end

function n2hex(num)
  return string.format("%x", num)
end

function getInt()
  local int = { string.unpack("I4", f:read(4), 1) }
  return int[1]
end

function getIntHex()
  return n2hex(getInt())
end

function getShort()
  local short = { string.unpack("H", f:read(2), 1) }
  return short[1]
end

function getShortHex()
  return n2hex(getShort())
end

function abort(msg)
  io.stderr:write(msg .. "\n")
  os.exit()
end

function extract(name, offset, length)
  of = io.open(name, "wb")
  f:seek("set", offset)
  of:write(f:read(length))
  of:close()
end

if #arg < 1 then
  abort("Usage: da-dump.lua dafile [-d]")
end

f = io.open(arg[1], "rb")

fsize = f:seek("end")
f:seek("set")

-- 108 bytes header at start
if f:read(18) ~= "MTK_DOWNLOAD_AGENT" then
  abort("Unsupported file")
end
f:read(14) --skip

print("# Mediatek Download Agent information dump")
id = getString(64)
print("ID: " .. id)
if arg[#arg] == "-d" then
  id = id:gsub("[/|:]", "-")
  os.execute("mkdir " .. id) -- not Portable
end

if getInt() ~= 4 then
--  abort("Error1")
end

if f:read(4) ~= "\x99\x88\x66\x22" then
  abort("Error2")
end

chips = {}
chips_sort = {}
count = getInt()
dataoff = 0
datalen = 0
for i = 1, count do
  -- $count headers of 220 bytes length consists of chip info
  f:seek("set", 108 + ((i - 1) * 220))
  chips[i] = {
    magic = f:read(2), -- DADA
    hw_code = getShortHex(),
    hw_sub_code = getShortHex(),
    hw_version = getShortHex(),
    sw_version = getShortHex(),
    reserved1 = getShortHex(),
    pagesize = getShortHex(),
    reserved2 = getShortHex(),
    entry_region_index = getShortHex(),
    entry_region_count = getShortHex(),

    regions = {},
  } -- 20 byte header, remaining 200 bytes are region headers with each 20 byte
  if chips[i].magic ~= "\xda\xda" then
    f:close(); abort("DADA magic not found")
  end

  if arg[#arg] ~= "-d" then
    chips_sort[i] = chips[i].hw_code
  end

 if arg[#arg] == "-d" then
  print()

  dirname = id .. "/" .. chips[i].hw_code .. "-" .. chips[i].hw_version .. "-" .. chips[i].hw_sub_code
  print("Writing to " .. dirname .. "...")
  print("[MT" .. chips[i].hw_code .. "] region_offset, size,   load_addr")
  os.execute("mkdir " .. dirname)
  for j = 1, chips[i].entry_region_count do
    f:seek("set", 108 + ((i - 1) * 220) + 20 + ((j-1)*20))
    chips[i].regions[j] = {
      m_buf = getInt(),
      m_len = getInt(),
      m_start_addr = getInt(),
      m_start_offset = getInt(),
      m_sig_len = getInt(),
    } -- 20 byte region header
    offset = chips[i].regions[j].m_buf
    length = chips[i].regions[j].m_len -- including sig
    sig_offset = chips[i].regions[j].m_start_offset -- offset from above region offset
    sig_len = chips[i].regions[j].m_sig_len
    start_addr = chips[i].regions[j].m_start_addr
 
    print(string.format("da_part%d : [0x%07x, 0x%05x, 0x%08x]", (j-1), offset, length, start_addr))

    if dataoff == 0 then dataoff = offset end
    datalen = datalen + length

    region_name = (j - 1) .. "-" .. n2hex(start_addr)
    extract(dirname .. "/" .. region_name, offset, length)
--    if sig_len ~= 0 then
--      extract(dirname .. "/" .. region_name .. ".sig", offset + sig_offset, sig_len)
--    end
  end
 end
end

if arg[#arg] ~= "-d" then
  for i = 1, count do
    table.sort(chips_sort)
    print(string.format("%2d. MT%s", i, chips_sort[i]))
  end
else
  print()
  hdrssize = 108 + count*220
  unknowndatasize = dataoff - hdrssize
  if fsize == hdrssize + datalen then
    print("perfect")
  elseif fsize == hdrssize + unknowndatasize + datalen then
    f:seek("set", hdrssize)
    unknowndat = f:read(unknowndatasize)
    unknowndat = unknowndat:gsub("\x00", "")
    if #unknowndat == 0 then
      print(string.format("perfect with unknown %d nulls structure at middle(offset %#x) after headers", unknowndatasize, hdrssize))
    else
      print(string.format("perfect with unknown %d bytes structure at middle(offset %#x) after headers", unknowndatasize, hdrssize))
      extract("unknowndat", hdrssize, unknowndatasize)
    end
  else
    print("Not perfect")
  end
end

f:close()
