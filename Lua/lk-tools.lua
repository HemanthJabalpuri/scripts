#!/usr/bin/env lua
-- tools for LK partition file MTK
-- Ref:
--   lk_parser.py written by @R0rt1z2 (Github) under GPLv3 License
--   https://github.com/arturkow2000/lgk10exploit/blob/master/partinfo.py

pos = 0 -- file pointer

function getString(n)
  local dat = read(n)
  return dat:gsub("\x00", "")
end

function getInt()
  local int = { string.unpack("I4", read(4), 1) }
  return int[1]
end

function getSignedInt()
  local int = { string.unpack("i4", read(4), 1) }
  return int[1]
end

function b2hex(dat)
  return (dat:gsub('.', function (c) return string.format('%02x', c:byte()) end))
end

function abort(msg)
  io.stderr:write(msg .. "\n")
  os.exit()
end

function seek(off)
  pos = off
end

function read(n)
  bytes = dat:sub(pos+1, pos+n)
  pos = pos + n
  return bytes
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

function find_after_pos(str, pos)
  local addr, j
  addr, j = dat:find(str, pos)
  if addr then
    return addr - 1
  end
  return addr
end

function exists_in_file(str)
  if dat:find(str) then
    return "true"
  end
  return "false"
end

function contains(table, val)
 for i=1,#table do
   if table[i] == val then 
     return true
   end
 end
 return false
end

if #arg < 1 then
  abort("Usage: lk-tools.lua lk.bin")
end


f = io.open(arg[1], "rb")
dat = f:read("a") -- read whole file to dat
f:close()


function extract(name, offset, length)
  of = io.open(name, "wb")
  seek(offset)
  of:write(read(length))
  of:close()
end



function oplus_unlock()
  SEQUENCES = {
    "\x2d\xe9\xf0\x4f\xad\xf5\xac\x5d", -- Android 9
    "\xf0\xb5\xad\xf5\x92\x5d"          -- Android 10/11
  }
  sequence = nil
  if read(4) == "BFBF" then seek(0x4040)
  else seek(1)
  end

  if read(4) ~= "\x88\x16\x88X" then
    abort("invalid magic")
  end
  sequence_off = nil
  for i, lock_hex in ipairs(SEQUENCES) do
    off, j = dat:find(lock_hex)
    if off then
      sequence = lock_hex
      sequence_off = off
    end
  end
  if not sequence_off then
    abort("no suitable sequence was found")
  end
  of = io.open("lk-patched.bin", "wb")
  -- 00 20 => movs r0, #0x0
  -- 70 47 => bx   lr
  patched_seq = sequence:gsub(sequence:sub(1, 4), "\x00\x20\x70\x47", 1)
  new_dat, j = dat:gsub(sequence, patched_seq, 1)
  of:write(new_dat)
  of:close()
  print("patched " .. b2hex(sequence) .. " at offset " .. string.format("%#x", sequence_off-1))
end

if arg[2] == "--oplus-unlock" then
  oplus_unlock()
  os.exit()
end



function remove_orange_state()
  str = "Orange State"
  addr  = find(str)
  print(" Orange state warning found at offset " .. string.format("%#x", addr-1))
  new_dat, j = dat:gsub(str, string.rep("\x00", #str), 1)

  str = "Your device has been unlocked and can't be trusted"
  new_dat, j = new_dat:gsub(str, string.rep("\x00", #str), 1)

  str = "Your device will boot in 5 seconds"
  new_dat, j = new_dat:gsub(str, string.rep("\x00", #str), 1)

  of = io.open("lk-orange-state-removed.bin", "wb")
  of:write(new_dat)
  of:close()
end

if arg[2] == "--orange-state-disabler" then
  remove_orange_state()
  os.exit()
end



function dump_header(offset)
  seek(offset)
  has_ext = false

  magic = read(4)
  if magic ~= "\x88\x16\x88X" then
    abort("invalid magic value, expected 0x" .. b2hex("\x88\x16\x88X") .. " got 0x" .. b2hex(magic) .. "")
  end

  data_size = getInt()
  name = getString(32)
  addressing_mode = getSignedInt()
  memory_address = getInt()

  image_list_end = 0
  header_size = 512
  alignment = 8

  if read(4) == "\x89\x16\x89X" then
    has_ext = true
    header_size = getInt()
    header_version = getInt()
    image_type = getInt()
    image_list_end = getInt()
    alignment = getInt()
    data_size = data_size | getInt() << 32
    memory_address = memory_address | getInt() << 32
  end

  print("Partition Name:  " .. name)
  print("Data Size:       " .. data_size)

  if addressing_mode == -1 then
    print("Addressing Mode: NORMAL")
  elseif addressing_mode == 0 then
    print("Addressing Mode: BACKWARD")
  else
    print(string.format("Addressing Mode: UNKNOWN(0x%08x)", addressing_mode))
  end

  if memory_address & 0xffffffff == 0xffffffff then
    print("Address:         DEFAULT")
  else
    print(string.format("Address:         %#x", memory_address))
  end

  if has_ext then
    print("Header Size:     " .. header_size)
    print("Header Version:  " .. header_version)
    print(string.format("Image Type:      %#x", image_type))
    print("Image List End:  " .. image_list_end)
    print("Alignment:       " .. alignment)
  end

  new_offset = offset + header_size + data_size
  if alignment ~= 0 and (new_offset % alignment ~= 0) then
    extra = alignment - (new_offset % alignment)
    new_offset = new_offset + extra
  end

  if image_list_end == 1 then
--    print("last file")
    if #dat ~= new_offset then
      abort("error")
    end
  end
  foffset = offset + header_size
--  extract(string.format("%x_%s", offset-1, name), foffset, (new_offset-foffset)+1)

  if image_list_end ~= 1 then -- some more headers there
    return new_offset
  else
    return nil
  end
end


n = dump_header(0)
while n do
  print()
  n = dump_header(n)
end
print()


--seek(5)
--print("[?] Image size (from header): " .. getInt() .. " bytes")
--print("[?] Image name (from header): " .. getString(8))


-- parse_lk_version
--[[
addr = find("getvar:")
n = 0
seek(addr + 7 + 9)
while read(1) ~= "\x00" do
  n = n + 1
end
seek(addr + 7 + 8)
print("[?] LK version: " .. read(n))
]]


-- parse_lk_cmdline
addr = find("console=")
n = 0
seek(addr)
while read(1) ~= "\x00" do
  n = n + 1
end
seek(addr)
print("[?] Command Line: " .. read(n))


-- parse_lk_platform
addr = find("platform/")
seek(addr+9)
print("[?] Platform: " .. getString(6))


-- parse_lk_product
addr = find("product\x00")
n = 0
seek(addr+8)
while read(1) ~= "\x00" do
  n = n + 1
end
seek(addr+8)
print("[?] Product: " .. getString(n))
 

print("[?] Needs unlock code: " .. exists_in_file("unlock code"))
print("[?] Uses verified boot: " .. exists_in_file("verified boot"))
print("[?] Factory reset protection (FRP): " .. exists_in_file("frp"))
print("[?] FOTA support: " .. exists_in_file("fota"))


function find_str_offsets(str)
  local str_offsets = {}
  local addr = find(str)
  if not addr then return addr end
  str_offsets[1] = addr
  local i = 2
  while addr do
    addr = find_after_pos(str, str_offsets[i-1] + #str)
    if addr then
      str_offsets[i] = addr
      i = i + 1
    end
  end
  return str_offsets
end

-- parse_lk_oem_commands
str_offsets = find_str_offsets("oem ")
io.write("[?] Available OEM commands: [")
if str_offsets then
  cmds = {}
  for i, offset in ipairs(str_offsets) do
    seek(offset+4)
    str = ""
    tmpchr = getString(1)
    while tmpchr ~= "\\" and tmpchr ~= "[" and tmpchr ~= "'" and 
        tmpchr ~= "\n" and tmpchr ~= " " and tmpchr ~= "(" and 
        tmpchr ~= ")" and tmpchr ~= ":" and tmpchr ~= "" do
      str = str .. tmpchr
      tmpchr = getString(1)
    end
    if not contains(cmds, str) then
      io.write("'fastboot oem " .. str .. "', ") 
      cmds[i] = str
    end
  end
else
  io.write("None")
end
print("]")


-- parse_lk_atags
str_offsets = find_str_offsets("atag,")
io.write("[?] LK ATAGs: [")
if str_offsets then
  for i, offset in ipairs(str_offsets) do
    n = 0
    seek(offset)
    while read(1) ~= "\x00" do
      n = n + 1
    end
    seek(offset)
    io.write("'" .. getString(n) .. "', ") 
  end
else
  io.write("None")
end
print("]")
