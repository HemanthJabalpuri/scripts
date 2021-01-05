#!/system/bin/sh
# Some common busybox utils using shell
# grep ls dirname basename touch cat cp head tail seq cut rev readlink which mv
# above applets are made with very common options that will work wil mksh and bash

# grep_ <-m|-q> #only used in piping
grep_() {
  local entry count
  case "$1" in
    -m) entry="$3";;
    -q) entry="$2";;
    -*) return;;
    *) entry="$1";;
  esac
  count=0
  while read line; do
    case "$line" in
      *"$entry"*)
        [ "$1" = "-q" ] && return 0 || echo "$line"
        if [ ! -z "$3" ]; then
          count=$((count+1))
          [ $count -eq $2 ] && return
        fi
      ;;
    esac
  done
  if [ "$1" == "-q" ]; then return 1; fi
}

# ls_ <dir/file>
ls_() {
  [ -f "$1" ] && echo "$1" && return
  for i in $1/*; do
    echo "${i##*/}"
  done
}

# dirname_ <PATH>
dirname() {
  local dir="$1"
  local tdir="${dir%/}"
  while [ "$tdir" != "$dir" ]; do
    tdir="$dir"
    dir="${tdir%/}"
  done
  echo "${dir%/*}"
}

# basename_ <PATH> [<suffix>]
basename() {
  local path="$1"
  local suffix="$2"
  local tpath="${path%/}"
  while [ "$tpath" != "$path" ]; do
    tpath="$path"
    path="${tpath%/}"
  done
  path="${path##*/}"
  echo "${path%$suffix}"
}

# touch_ <FILE>
touch_() {
  true >> "$1"
}

# cat_ <FILE>
cat_() {
  while read line; do
    echo "$line"
  done < "$1"
}

# cp_ <src> <dst>
cp_() {
  cat "$1" > "$2"
}

# mv_ <src> <dst>
mv_() {
  rename "$1" "$2"
}

# head_ -n <count> <FILE>
head_() {
  local a=1
  while read line; do
    echo "$line"
    [ "$a" -eq "$2" ] && break
    a=$((a+1))
  done < "$3"
}

# tail_ -n <count> <FILE>
tail_() {
  local count a=1
  while read line; do
    a=$((a+1))
  done < "$3"
  count=$((a-$2))
  a=1
  while read line; do
    if [ "$a" -ge "$count" ]; then
      echo "$line"
    fi
    a=$((a+1))
  done < "$3"
}

# seq_ <count>
seq_() {
  local a=1
#  local a=2 l=1
  while true; do
#    l="$l $a"
    echo "$a"
    [ "$a" -eq "$1" ] && break
    a=$((a+1))
  done
#  echo "$l"
}

# cut_ -d <delimiter> -f <field count> <string>
cut_() {
#  local count pos char part part1 reqcount req
#  count="${#5}"
#  for i in `seq_ $count`; do
#    pos="$((i-1))"
#    char="${5:$pos:1}"
#    part="$part1"
#    part1="$part1$char"
#    if [ "$i" -eq "$count" ]; then
#      req="${part1##*$2}"
#    fi
#    if [ "$char" == "$2" ]; then
#      reqcount="$((reqcount+1))"
#      if [ "$reqcount" -eq "$4" ]; then
#        req="${part##*$2}"
#        break
#      fi
#    fi
#  done
#  echo "$req"
  local OIFS
  OIFS="$IFS"
  IFS="$2"
  a=1
  for i in $5; do
    if [ $a -eq $4 ]; then
      echo "$i"; break
    fi
    a=$((a+1))
  done
  IFS="$OIFS"
}

# rev_ <string>
rev_() {
  local count pos char part
  count="${#1}"
  for i in `seq_ $count`; do
    pos=$((i-1))
    char="${1:$pos:1}"
    part="$char$part"
  done
  echo "$part"
}

# readlink [-f] <link/file/dir>
readlink_() {
  local file
  [ "$2" ] && file="$2" || file="$1"
  realpath "$file"
}

# which_ [-a] command
which_() {
  a=""; file="$1"
  if [ "$1" = "-a" ]; then
    a=1; file="$2"
  fi
  path="$PATH"
  case "$path" in :*) path="${PWD}${path}"; esac
  case "$path" in *:) path="${path}${PWD}"; esac
  path="${path//::/:${PWD}:}"
  path="${path//:/ }"
  for x in $path; do
    if [ -x "$x/$file" ]; then
      echo "$x/$file"; found=1
      [ -z "$a" ] && break
    fi
  done
  echo "$found"
  [ "$found" = 1 ] || return 1
}

#only whole numbers
test_lt() {
  result="$((${1}-${2}))"
  echo $result
  case $result in
    -*) return 0;;
  esac
  return 1
}

#only whole numbers
test_gt() {
  result="$((${2}-${1}))"
  echo $result
  case $result in
    -*) return 0;;
  esac
  return 1
}

test_eq() {
  case "$1" in "$2") return 0;; esac
  return 1
}

test_z() {
  count=1
  for i in $1; do
    count=0
  done
  return $count
}

test_f() {
  ls "$1" >/dev/null 2>&1 || return 1
  test_d "$1" || return 0
  return 1
}

test_d() {
  (cd "$1") 2>/dev/null && return 0
  return 1
}
