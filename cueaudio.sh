#!/bin/bash
# cueflac flac [cue]

# You may provide a audio file (preferibly in FLAC format)

while [[ $# > 1 ]]
do
key="$1"

case $key in
    -a|--audiofile)
       audiofile="$2"
       shift
       ;;
       -c|--cuefile)
       cuefile="$2"
       shift
       ;;
       -d|--directory)
       directory="$2"
       shift
       ;;
       -p|--purge)
       purge="$2"
       shift
       ;;
       -v|--verbose)
       verbose="$2"
       shift
       ;;
       *)
       echo "Unknown flag"
       exit 1
       ;;
esac
shift
done



if [ -n "$audiofile" ] && [ -z "$cuefile" ]
then
    cuefile=${audiofile%.*}.cue
elif [ -z "$audiofile" ] && [ -z "$cuefile" ]
then
    echo Necesito al menos el nombre del archivo de audio
    exit 1
else
    echo No encuentro los archivos $audiofile ni $cuefile
    exit 1
fi

test -f "$audiofile" || exit 2
test -f "$cuefile" || exit 2


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


if [ "$status" = '0' ]
then
    echo OK
else
    echo Failed
fi
