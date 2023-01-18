#!/usr/bin/env lua
-- Dumps information in preloader of MT6765 (Realme C12)
-- Ref:
--  https://github.com/mr-m96/MTKPreloaderParser
--  https://github.com/Iscle/mtk_bloader_info_extractor


pos = 0 -- file pointer

function getString(n)
  local dat = read(n)
  return dat:gsub("\x00", "")
end

function b2hex(dat)
  return (dat:gsub('.', function (c) return string.format('%02X', c:byte()) end))
end

function n2hex(num)
  return string.format("%#x", num)
end

function getLong()
  local int = { string.unpack("I8", read(8), 1) }
  return int[1]
end

function getInt()
  local int = { string.unpack("I4", read(4), 1) }
  return int[1]
end

function getIntHex()
  return n2hex(getInt())
end

function getShort()
  local short = { string.unpack("H", read(2), 1) }
  return short[1]
end

function getShortHex()
  return n2hex(getShort())
end

function abort(msg)
  io.stderr:write(msg .. "\n")
  os.exit()
end

function getPos()
  return pos
end

function seek(off)
  pos = off
end

function read(n)
  bytes = dat:sub(pos+1, pos+n)
  pos = pos + n
  return bytes
end

function extract(name, offset, length)
  of = io.open(name, "wb")
  seek(offset)
  of:write(read(length))
  of:close()
end

function get_dram_type(type)
  if type == 0x206 then
    return "MCP(eMMC+LPDR4X)"
  elseif type == 0x306 then
    return "uMCP(eUFS+LPDDR4X)";
  else
    return "Unknown"
  end
end

function get_unit(bytes)
  local kb = 1024
  local mb = 1024 * kb
  local gb = 1024 * mb
  local tb = 1024 * gb
  if bytes >= tb then
    return (bytes / tb) .. " TiB"
  elseif bytes >= gb then
    return (bytes / gb) .. " GiB"
  elseif bytes >= mb then
    return (bytes / mb) .. " MiB"
  elseif bytes >= kb then
    return (bytes / kb) .. " KiB"
  end
  return bytes .. "B"
end

function poff()
  print("file is at offset " .. pos .. " " .. string.format("%#x", pos))
end

function find(str)
  local addr, j
  addr, j = dat:find(str)
  if addr then
    return addr - 1
  end
  return addr
end

function print_inf(off, n)
  if off+160-1 > #dat then
    print(off-1 .. " " .. #dat)
    abort("wrong chip count")
  end

  seek(off)
  sub_version = getInt()
  m_type = getInt()
  dram_type = get_dram_type(m_type)
  emmc_id_len = getInt()
  fw_id_len = getInt()
  emmc_id_hex = b2hex(read(emmc_id_len))
  seek(getPos() - emmc_id_len)
  emmc_id = getString(emmc_id_len)
  read(16-emmc_id_len) --skip

  fw_id = b2hex(read(8))

  read(40) --skip

  dram_rank_size = getLong() + getLong() + getLong() + getLong()

  print("--------Start element " .. n .. "--------")

  print("type: " .. n2hex(m_type) .. " (dram_type: " .. dram_type .. ")")
  if emmc_id_len > 0 then
    print("emmc_id: 0x" .. emmc_id_hex .. " (" .. emmc_id .. ")")
  end
  print("dram_rank_size: " .. get_unit(dram_rank_size))
  if fw_id_len > 0 then
    print("fw_id: 0x" .. fw_id)
  end

  print("--------End element " .. n .. "--------\n")
end

if #arg < 1 then
  abort("Usage: mtk_bloader_info_extractor.lua preloader.bin")
end

f = io.open(arg[1], "rb")
dat = f:read("a")
f:close()

hdr = getString(9)
if hdr ~= "EMMC_BOOT" and hdr ~= "UFS_BOOT" and hdr ~= "MTK_BLOAD" then
  abort("Not a preloader file")
end

print()


addr = find("BRLYT")
if addr then
  seek(addr)
  poff()
  print("brylt: " .. getString(16))
  print()
end

addr = find("FILE_INFO")
if addr then
  seek(addr)
  poff()
  print("fileinfo: " .. getString(16))
  print()
end

--for i=1, 11 do
--  print_inf(0x39A00+((i-1)*160), i)
--end

addr = find("AND_ROMINFO_v")
if addr then
  seek(addr + 20)
  print(string.format("Found AND_ROMINFO_v header at offset %#x!", addr))
  print("platform name: " .. getString(16))
  print("project name: " .. getString(16))
  print("secctrl_magic: " .. getString(16))
  read(16) --skip
  print("secro_magic: " .. getString(12))
  read(8) --skip
  print("CUSTOM_CRYPTO_SEED: " .. getString(16))
end



print()
magic = "MTK_BLOADER_INFO_v"
bloader_off = find(magic)
if not bloader_off then
  abort("Failed")
end
print(string.format("Found MTK_BLOADER_INFO header at offset %#x!", bloader_off))
seek(bloader_off+18)

c_ver = read(2)
if c_ver ~= "35" and c_ver ~= "45" then
  abort("Unsupported")
end

seek(bloader_off)

hdr = getString(27)
pre_bin = getString(61)
m_version = getString(4) --V116
m_chksum_seed = b2hex(read(4)) --22884433
m_start_addr = getIntHex()
mtk_bin = getString(8) -- MTK_BIN
total_custem_chips = getInt()

print("header: " .. hdr)
print("pre_bin: " .. pre_bin)
print("m_version: " .. m_version)
print("m_chksum_seed: " .. m_chksum_seed)
print("m_start_addr: " .. m_start_addr)
print("mtk_bin: " .. mtk_bin)
print("total_custem_chips: " .. total_custem_chips .. "\n")

for i = 1, total_custem_chips do
  print_inf(bloader_off + 112 + (i-1)*160, i) -- size 160
end

small_preloader_len = 112 + total_custem_chips*160
if #dat - bloader_off + 1 == small_preloader_len then
  print("small preloader")
else
  print("Extracting small preloader to '" .. pre_bin .. "'...")
--  extract(pre_bin, bloader_off, small_preloader_len)
end

