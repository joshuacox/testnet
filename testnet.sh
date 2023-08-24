#!/usr/bin/env bash
NOW=$(date +'%s')

: ${CONFIG_FILE:=/root/.testnet}
if [[ -f $CONFIG_FILE ]]; then
  . $CONFIG_FILE
else
  echo "$CONFIG_FILE not found" 
  echo "$CONFIG_FILE not found" >> /var/log/network-failures.log
  exit 1
fi
# settable variables
: ${VERBOSITY:=0}
: ${NET_FAIL_LOG:=/var/log/network-failures.log}
: ${BAD_IPS:=/var/log/.bad_ips}
: ${GOOD_IPS:=/var/log/.good_ips}
if [[ -z $this_class_c ]]; then
    echo 'this_class_c is not set'
    echo 'this_class_c is not set' >> /var/log/network-failures.log
    exit 1
fi
if [[ -z $known_pingz ]]; then
    known_pingz=('1.1.1.1')
    known_pingz+=('8.8.8.8')
    known_pingz+=('8.8.4.4')
    known_pingz+=('apple.com')
    known_pingz+=('microsoft.com')
fi
if [[ -z $local_pingz ]]; then
    local_pingz=('google.com')
fi

TMP=$(mktemp -d)
#functions
cleanup () {
  rmdir $TMP
  THEN=$(date +'%s')
  phrase=$(printf '%s took %s seconds ' "$0" "$(($THEN - $NOW))")
  squawk 3 "$phrase"
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
      printf '\t'
      printf "$squawk"
      printf '\n'
    else
      printf '#>{ '
      printf '%s' "$squawk_lvl"
      printf ' }<# '
      printf "$squawk"
      printf '\n'
    fi
  fi
}

test () {
  ping $ping_timeout_flag 1 -c 1 $1 &>/dev/null
  if [[ $? -eq 0 ]]; then
    phrase=$(printf '%s\tgood' $1)
    echo -n "$1," >> $GOOD_IPS
    date +%Y-%m-%d-%H:%M:%S,%s     >> $GOOD_IPS
    squawk 2 "$phrase"
    exit 0
  else
    phrase=$(printf '%s\tbad' $1)
    squawk 1 "$phrase"
    echo "$1" >> $BAD_IPS
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

loop_pingz () {
  count=0
  for i in "${pingz[@]}"
  do
    if [[ $count -lt 15 ]];then
      test $i
      squawk 5 "$i"
    fi
  done
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
touchr $GOOD_IPS
touchr $NET_FAIL_LOG

count=0
while [[ $count -lt 3 ]]; do
  rand1=$(( RANDOM % 254 ))
  rand2=$(( RANDOM % 254 ))
  rand3=$(( RANDOM % 254 ))
  rand4=$(( RANDOM % 254 ))
  test "$rand1.$rand2.$rand3.$rand4"
done

BAD_IPS_COUNT=$(grep $this_class_c $BAD_IPS|wc -l|awk '{print $1}')
if [[ $BAD_IPS_COUNT -gt 225 ]]; then
  squawk 7 "clearing $BAD_IPS"
  grep -v $this_class_c $BAD_IPS | sort | uniq >> $TMP/bad_ips
  mv $TMP/bad_ips $BAD_IPS
  touch $BAD_IPS
fi


touch $TMP/good_ips
while IFS="," read -r goodip gooddate goodepoch
do
  echo "$goodip" >> $TMP/good_ips
  good_pingz+=("$goodip")
done < <(cat $GOOD_IPS)
sort $TMP/good_ips|uniq > $TMP/good_uniq_ips
rm $TMP/good_ips

# slurp ips into an arrays
for i in $(cat $TMP/good_uniq_ips)
do
 both_ips_array+=("$i")
 good_pingz+=("$i")
done
rm $TMP/good_uniq_ips
for i in $(cat $BAD_IPS)
do
 both_ips_array+=("$i")
 bad_ips_array+=("$i")
done

# convert array into associative array
declare -A map    # required: declare explicit associative array
#for key in "${!bad_ips_array[@]}"; do map[${bad_ips_array[$key]}]="$key"; done  # see below
for key in "${!both_ips_array[@]}"; do map[${both_ips_array[$key]}]="$key"; done  # see below
for i in {2..254};do
  this_ip="${this_class_c}.${i}"
  if [[ -n "${map[$this_ip]}" ]]; then
    continue
    #echo $this_ip known
  else
    local_pingz+=("$this_ip")
  fi
done

# note some perf data
THEN=$(date +'%s')
DateDiff=$(($THEN - $NOW))
phrase=$(printf 'The for loop took %s seconds \n' "$DateDiff")
squawk 6 "The for loop took $DateDiff seconds"

# test 15 of our local pings
perm "${local_pingz[@]}"
# perm results in a shuffled array "pingz"
loop_pingz
# test known good pings
perm "${good_pingz[@]}"
loop_pingz
# test widely known pings
perm "${known_pingz[@]}"
loop_pingz

# If both of those for loops passed network is not pinging
# log the failure with some details
echo '__________________________________________' >> ${NET_FAIL_LOG}
ifconfig                       >> ${NET_FAIL_LOG}
echo -n 'Network failure at: ' >> ${NET_FAIL_LOG}
date +%Y-%m-%d-%H:%M:%S-%s     >> ${NET_FAIL_LOG}
ifconfig
echo -n 'Network failure at: '
date +%Y-%m-%d-%H:%M:%S-%s

# only reboot if all pings fail
echo reboot >> ${NET_FAIL_LOG}
echo "NET_FAIL_LOG ${NET_FAIL_LOG}" >> ${NET_FAIL_LOG}
reboot
exit 1
