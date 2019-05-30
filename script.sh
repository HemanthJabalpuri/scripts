#!/system/bin/sh
# Some common busybox utils using shell
# grep ls dirname basename touch cat cp head tail seq cut rev
# above applets are made with very common options

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
dirname_() {
  local dir
  case "$1" in
    */*) dir=${1%/*}; [ -z $dir ] && echo "/" || echo $dir ;;
    *) echo "." ;;
  esac
}

# basename_ <PATH>
basename_() {
  echo "${1##*/}"
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
  cat_ "$1" > "$2"
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
  local count pos char part part1 req2 reqcount req
  count="${#5}"
  for i in `seq_ $count`; do
    pos="$((i-1))"
    char="${5:$pos:1}"
    part="$part1"
    part1="$part1$char"
    if [ "$i" -eq "$count" ]; then
      req2="${part1##*$2}"
    fi
    if [ "$char" == "$2" ]; then
      reqcount="$((reqcount+1))"
      if [ "$reqcount" -eq "$4" ]; then
        req="${part##*$2}"
        req2="${req%%$2*}"
        break
      fi
    fi
  done
  echo "$req2"
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

# which_ command
which_() {
  local entry
  for i in ${PATH//:/ }; do
    if [ -f "$i/$1" ]; then
      entry="$i/$1"; break
    else
      entry=""
    fi
  done
  [ -z "$entry" ] && return 1
  echo "$entry"
}

