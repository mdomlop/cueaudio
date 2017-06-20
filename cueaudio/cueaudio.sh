#!/bin/bash

# Splits an audio file with a CUE sheet.
# You may provide a audio file (preferibly in FLAC format)


function help
{
    echo USAGE:
    echo cueaudio -a audiofile [-c cuefile] [-d directory] [-p] [-v]
}


function error
{
    echo $*
    exit 1
}

while getopts 'hpva:c:d:' opt
do
    case $opt in
        a) audiofile="$OPTARG";;
        c) cuefile="$OPTARG";;
        d) directory="$OPTARG";;
        p) purge='true';;
        v) verbose=0;;
        h) help; exit 0;;
        \?) echo "Unknown option: -$opt" >&2; exit 1;;
        :) echo "Missing option argument for -$opt" >&2; exit 1;;
        *) echo "Unimplemented option: -$opt" >&2; exit 1;;
    esac
done



if [ -z "$cuefile" ]
then
    if [ -z "$audiofile" ]
    then
        help
        exit 1
    else
        echo Audio: $audiofile
        test -f "$audiofile" || error File not exists: $audiofile

        echo Deducting CUE file name from audio file name...

        cuefile=${audiofile%.*}.cue
        echo CUE: $cuefile
        test -f "$cuefile" || error File not exists: $cuefile
    fi
elif [ -z "$audiofile" ]
then
    echo I need an audio file name.
    help
    exit 1
fi

echo Processing "$audiofile"...

charset=$(file -bi "$cuefile" | cut -d= -f2)
test "$CHARSET" != utf-8  &&
test "$CHARSET" != us-ascii &&
iconv -f "$charset" -t utf8 "$cuefile" -o "$cuefile" || exit 3

dos2unix -q "$cuefile" || exit 3


if [ -z "$directory" ]
then
    albumdir=$(dirname "$audiofile")
else
    albumdir="$directory"
    mkdir -p "$albumdir" || exit 4
fi


if [[ "$verbose" > 0 ]]
then
echo Archivo de audio: "$audiofile"
echo Archivo de cortes: "$cuefile"
echo Directorio: "$albumdir"
fi


if [[ "$verbose" > 0 ]]
then
echo STEP ONE: SPLITTING...
fi


cuebreakpoints "$cuefile" |
shnsplit -q -d "$albumdir" -o flac "$audiofile" &&
splitok='true'

if [ "$splitok" = 'true' ]
then
    if [ "$purge" = "true" ]
    then
        if [[ "$verbose" > 0 ]]
        then
            echo "Borrando $audiofile..."
        fi
        rm "$audiofile"
    fi
else
    echo Error splitting "$audiofile"
    exit 5
fi

if [[ "$verbose" > 0 ]]
then
    echo STEP TWO: TAGGING..
fi

cuetag.sh "$cuefile" "$albumdir"/split-track*.flac || exit 6

if [[ "$verbose" > 0 ]]
then
echo STEP THREE: RENAMING...
fi

for i in "$albumdir"/split-track*.flac; do
    TRACKNUMBER=$(metaflac "$i" --show-tag=TRACKNUMBER | sed s/.*=//g)
    TITLE=$(metaflac "$i" --show-tag=TITLE | sed s/.*=//g)
    ARTIST=$(metaflac "$i" --show-tag=ARTIST | sed s/.*=//g)
    ALBUM=$(metaflac "$i" --show-tag=ALBUM | sed s/.*=//g)
    FILENAME="$(echo -n $(printf %02g $TRACKNUMBER) - $TITLE - $ALBUM - $ARTIST.flac | tr '/' '+')"
    if [[ "$verbose" > 0 ]]
    then
        mv "$i" "$albumdir"/"$FILENAME"
    else
        mv "$i" "$albumdir"/"$FILENAME"
    fi
done
