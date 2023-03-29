#!/bin/bash
#
# ------------------------------------------------------------------
# Script for burn data or audio to CD or DVD in Linux
# usage: burn.sh [ /path/to/dir ]
# usage: or create /tmp/burn/ and put there symbolic links
# author: Aleksey K. <uu776080@gmail.com>
# thanks to: Tomas M. <http://www.linux-live.org>
# ------------------------------------------------------------------

clear
echo 'Welcome to burn script'
echo
WODIM=$(which wodim)
GENISO=$(which genisoimage)
if [ -z $WODIM ]
then
  echo "You have to install wodim"
  exit 1
fi

if [ -z $GENISO ]
then
  echo "You have to install genisoimage"
  exit 1
fi

WHOAMI=$(whoami)
if [ -n "$1" ]
then
  BURN_DIR="$1"
else 
  if [ -d /tmp/burn ]
  then
    BURN_DIR=/tmp/burn
  else
    echo "you need to pick a directory as first argument or create "/tmp/burn/"" 
    exit 1
  fi
fi

echo "Choose your case:"
echo
echo "1 - burn single session"
echo "2 - append to existing session"
echo "3 - burn audio disk"
echo "4 - burn linux-live (root required)"
echo
echo "and press Enter"

read KEYPR

clear

blank () {

  echo "Do you want to blank your disk before burning?"
  echo
  echo "1 - yes, blank fast"
  echo "2 - yes, blank all"
  echo
  echo "or press Enter to proceed without blanking"

  read KEYPR1

  case $KEYPR1 in
    "1" )
      echo "Wait for blanking disk"
      $WODIM blank=fast &
      ;;
    "2" )
      echo "Wait for blanking disk"
      $WODIM blank=all &
      ;;
  esac

  P1=$!
}


DISK_LABEL="disk"
TSIZE="$(genisoimage -R -q -f -print-size "$BURN_DIR")"
BURN_DEV="/dev/sr0"

case $KEYPR in
  "1" )
    blank
    wait $P1
    cd "$BURN_DIR" && $GENISO -v -J -R -D -f -A $DISK_LABEL -V $DISK_LABEL . | $WODIM -v -eject -multi -tsize=$TSIZE"s" -
    ;;
  "2" )
    blank
    wait $P1
    MSINFO="$(wodim -msinfo dev="$BURN_DEV")"
    cd "$BURN_DIR" && $GENISO -v -J -R -D -f -A "$DISK_LABEL" -V "$DISK_LABEL" -C "$MSINFO" -M "$BURN_DEV" . | $WODIM -v -eject -multi -tsize=$TSIZE"s" -
    ;;
  "3" )
    blank
    NORMALIZE=$(which normalize-audio)
    FLAC=$(which flac)
    if [ -z $NORMALIZE ]
    then
      echo "You have to install normalize-audio"
      exit 1
    fi
    if [ -z $FLAC ]
    then
      echo "You have to install flac"
      exit 1
    fi
    FULL_LENGTH=$(LENGTH=0; for file in "$BURN_DIR"/*; do if [ -f "$file" ]; then LENGTH="$LENGTH+$(ffprobe -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)"; fi; done; echo "$LENGTH" | bc | awk '{print int($1+0.5)}')
    MAX_LENGTH=4800
    if [ $FULL_LENGTH -ge $MAX_LENGTH ]
    then
      echo "Your album can not fit on disk"
      exit 1
    fi
    MUSDIR=/tmp/music-$$
    mkdir -p $MUSDIR
    for file in "$BURN_DIR"/*.flac
    do 
      $FLAC -d "$file" -F -o $MUSDIR/"$(basename "$file")".wav
    done
    $NORMALIZE $MUSDIR/*
    wait $P1
    $WODIM -v -eject -audio -pad -dao $MUSDIR/*
    rm -r $MUSDIR
    ;;
  "4" )
    blank
    wait $P1
    cd "$BURN_DIR" && sudo $GENISO -v -J -R -D -f -A $DISK_LABEL -V $DISK_LABEL -no-emul-boot -boot-info-table -boot-load-size 4 -b linux/boot/isolinux.bin -c linux/boot/isolinux.boot . | $WODIM -v -eject -tsize=$TSIZE"s" -
    ;;
  * )
    echo "exited"
    exit 0
    ;;
esac

exit 0
