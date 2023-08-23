#!/usr/bin/env bash
NOW=$(date +'%s')

: ${CONFIG_FILE:=$HOME/.testnet}
if [[ -f $HOME/.testnet ]]; then
  . $CONFIG_FILE
fi
# settable variables
: ${VERBOSITY:=0}
: ${NET_FAIL_LOG:=/var/log/network-failures.log}
: ${known_pingz:=('microsoft.com')}
: ${local_pingz:=('google.com')}
: ${BAD_IPS:=/var/log/.bad_ips}
: ${this_class_c:="10.0.0"}

#functions
cleanup () {
  THEN=$(date +'%s')
  squawk 1 "$0 took $(($THEN - $NOW)) seconds "
}
trap cleanup EXIT

squawk () {
  # This function simplifies error reporting and verbosity
  # and it always prints its message along with anything in $error_report_log
  # call it by preceding your message with a verbosity level
  # e.g. `squawk 3 "This is a squawk"`
  # if the current verbosity level is greater than or equal to
  # the number given then this function will echo out your message
  # and pad it with # to let you now how verbose that message was
  squawk_lvl="$1"
  shift
  squawk="$@"

  if [[ "$VERBOSITY" -ge "$squawk_lvl" ]] ; then
    if [[ "$squawk_lvl" -le 20 ]] ; then
      count_squawk=0
      while [[ "$count_squawk" -lt "$squawk_lvl" ]]; do
        printf '#'
        ((++count_squawk))
      done
      printf ' %s\n' "$squawk"
    else
      printf '#>{ '
      printf '%s' "$squawk_lvl"
      printf ' }<# '
      printf ' %s\n' "$squawk"
    fi
  fi
}

test () {
  ping $ping_timeout_flag 1 -c 1 $1 &>/dev/null
  if [[ $? -eq 0 ]]; then
    squawk 2 $i good
    exit 0
  else
    squawk 2 $i bad
    echo "$i" >> $BAD_IPS
   ((++count)) 
  fi 
}

touchr () {
  # check the BAD_IPS file
  if [[ ! -f $1 ]]; then
    touch $1
    if [[ ! $? -eq 0 ]]; then
      echo "Error cannot touch $1"
      exit 1
    fi
  fi
}

# Randomly permute the arguments and put them in array 'pingz'
function perm
{
    pingz=( "$@" )

    # The algorithm used is the Fisher-Yates Shuffle
    # (https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle),
    # also known as the Knuth Shuffle.

    # Loop down through 'pingz', swapping the item at the current index
    # with a random item chosen from the array up to (and including) that
    # index
    local idx rand_idx tmp
    for ((idx=$#-1; idx>0 ; idx--)) ; do
        rand_idx=$(( RANDOM % (idx+1) ))
        # Swap if the randomly chosen item is not the current item
        if (( rand_idx != idx )) ; then
            tmp=${pingz[idx]}
            pingz[idx]=${pingz[rand_idx]}
            pingz[rand_idx]=$tmp
        fi
    done
}
# Declare 'pingz' for use by 'perm'
declare -a pingz

# check if we are on linux otherwise assume we are on BSD
os=$(uname -o)
if [[ $os == 'GNU/Linux' ]]; then
  ping_timeout_flag='-W'
else
  ping_timeout_flag='-t'
fi

touchr $BAD_IPS
touchr $NET_FAIL_LOG
BAD_IPS_COUNT=$(wc -l $BAD_IPS|awk '{print $1}')
if [[ $BAD_IPS_COUNT -gt 225 ]]; then
  echo clearing $BAD_IPS
  cat $BAD_IPS >> $BAD_IPS.historical
  rm -v $BAD_IPS
  touch $BAD_IPS
fi

# slurp bad ips into an array
for i in $(cat $BAD_IPS)
do
 bad_ips_array+=("$i")
done

# convert array into associative array
declare -A map    # required: declare explicit associative array
for key in "${!bad_ips_array[@]}"; do map[${bad_ips_array[$key]}]="$key"; done  # see below
for i in {2..254};do
  this_ip="${this_class_c}.${i}"
  if [[ -n "${map[$this_ip]}" ]]; then
    continue
    #echo $this_ip known bad
  else
    local_pingz+=("$this_ip")
  fi
done

# note some perf data
THEN=$(date +'%s')
squawk 5 "The for loop took $(($THEN - $NOW)) seconds "

# test 15 of our local pings
count=0
perm "${local_pingz[@]}"
# perm results in a shuffled array "pingz"
for i in "${pingz[@]}"
do
  if [[ $count -lt 15 ]];then
    test $i
    squawk 10 $i
  fi
done

# test known good pings
perm "${known_pingz[@]}"
# perm results in a shuffled array "pingz"
for i in "${pingz[@]}"
do
  test $i
  squawk 10 $i
done

# If both of those for loops passed network is not pinging
# log the failure with some details
echo -n 'Network failure at: ' >> ${NET_FAIL_LOG}
date +%Y-%m-%d-%H:%M:%S-%s >> ${NET_FAIL_LOG}
ifconfig >> ${NET_FAIL_LOG}

# only reboot if all pings fail
reboot
exit 1
