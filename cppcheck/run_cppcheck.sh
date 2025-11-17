#!/bin/bash

opt_c=0
opt_e=0
opt_x=0
while getopts ":cehxq" opt; do
    case ${opt} in
        c) opt_c=1 ;;
        e) opt_e=1 ;;
        q) QUIET="-q" ;;
        x) opt_x=1 ;;
        h|\?)
            echo "Usage: $0 [-ceqx]"
            echo "  -c : Perform configuration check."
            echo "  -e : Generate output that can be loaded into emacs."
            echo "  -q : Only print something when there is an error."
            echo "  -x : Don't generate xml output."
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# Path to source code root
SOURCE_DIR=${SOURCE_DIR:-"."}
# Directory containing the suppressions.txt for cppcheck
CONFIG_DIR=${CONFIG_DIR:-`dirname $0`}
# Directory to write out the cppcheck.xml and index.html
OUTPUT_DIR=${OUTPUT_DIR:-"."}
# Directory containing generate_cppcheck_report.pl
BIN_DIR=${BIN_DIR:-$CONFIG_DIR}

PATH=$PATH:/usr/local/bin
# unusedFunction check can't be used with '-j' option.
JOBS_LIMIT=1
TV_SUPPRESSIONS_LIST=$CONFIG_DIR/suppressions.mythtv.txt
PL_SUPPRESSIONS_LIST=$CONFIG_DIR/suppressions.mythplugins.txt
# Dynamically add qt5 header location to the includes file
cp -f $CONFIG_DIR/includes.txt $CONFIG_DIR/includes-qt5.txt
pkg-config --cflags-only-I Qt5Core | sed -e 's/\s/\n/g' | sed -e 's/^-I//g' | grep -v QtCore >> $CONFIG_DIR/includes-qt5.txt
INCLUDES_LIST=$CONFIG_DIR/includes-qt5.txt
sed -e "s#^#${CONFIG_DIR}/#" $CONFIG_DIR/includes-plugins.txt > $CONFIG_DIR/includes-qt5-plugins.txt
cat $CONFIG_DIR/includes-qt5.txt >> $CONFIG_DIR/includes-qt5-plugins.txt
INCLUDES_LIST_PL=$CONFIG_DIR/includes-qt5-plugins.txt

# Ignore directories in mythtv
TV_IGNORE_DIRS="-i filters/ -i libs/libmythmpeg2/ -i libs/libmythfreemheg/ -i libs/libmythfreesurround/"
# Add direcories that are never compiled
TV_IGNORE_DIRS+=" -i programs/mythbackend/services/ -i programs/mythbackend/serviceHosts/"
for dir in `cd $SOURCE_DIR/mythtv; find . -name contrib -prune -o -name external -prune  -o -name test -prune  -o -name moc -prune ` ; do
    TV_IGNORE_DIRS+=" -i $dir"
done

# Ignore directories in mythplugins
PL_IGNORE_DIRS=""
for dir in `cd $SOURCE_DIR/mythplugins; find . -name contrib -prune -o -name external -prune  -o -name test -prune  -o -name moc -prune ` ; do
    PL_IGNORE_DIRS+=" -i $dir"
done

CHECK_CONFIGS="-DBigEndian_ -D__BIG_ENDIAN__ -DBSD -DCOLOR_BGRA -D__cplusplus -D__GNUC__ -DIP_MULTICAST_IF -DLAME_WORKAROUND -DLATER -Dlinux -D__linux__ -DMETA_API -DMINILZO_HAVE_CONFIG_H -Dmm_flags -DMMX -D_MSC_VER -DMUI_API -DMYTH_BUILD_CONFIG -DMYTH_IMPLEMENT_VERBOSE -DNO_ERRNO_H -DNO_MYTH -D__OpenBSD__ -DPA_MAJOR -DPGM_CONVERT_GREYSCALE -D_POSIX_PRIORITY_SCHEDULING -DPOWERPC -DPROTOSERVER_API -DQ_OS_MACOS -DSERVICE_API -DSIGBUS -DSNDCTL_DSP_GETODELAY -DSPEW_FILES -DSTANDALONE -DSTDC -DSTRICT_COMPAT -DUPNP_API -D__MINGW32__ -D_WIN32 -DV4L2_CAP_SLICED_VBI_CAPTURE -DVDP_DECODER_PROFILE_MPEG4_PART2_ASP -DHAVE_3DNOW -DHAVE_ATHLON -DHAVE_CONFIG_H -DHAVE_MMX -DHAVE_MMX2 -DHAVE_SSE -DHAVE_STDINT_H -DHAVE_LIBUDFREAD -DCONFIG_ALSA -DCONFIG_APPLEREMOTE -DCONFIG_ASI -DCONFIG_AUDIO_JACK -DCONFIG_AUDIO_PULSE -DCONFIG_AUDIO_PULSEOUTPUT -DCONFIG_BACKEND -DCONFIG_CETON -DCONFIG_DARWIN_DA -DCONFIG_DVB -DCONFIG_DXVA2 -DCONFIG_FIREWIRE -DCONFIG_FIREWIRE_LINUX -DCONFIG_FIREWIRE_OSX -DCONFIG_HDHOMERUN -DCONFIG_IPTV -DCONFIG_JOYSTICK_MENU -DCONFIG_LIBASS -DCONFIG_LIRC -DCONFIG_MHEG -DCONFIG_OPENGL -DCONFIG_OSS -DCONFIG_QTDBUS -DCONFIG_V4L2 -DCONFIG_VAAPI -DCONFIG_VALGRIND -DCONFIG_VDPAU -DCONFIG_X11 -DUSE_ASM -DUSE_MOUNT_COMMAND -DUSING_FFMPEG_THREADS"
HTML_FILE="index.html"

# Switch to the source directory to get relative paths in output
#cd $SOURCE_DIR

CM_OPTIONS="$QUIET -j$JOBS_LIMIT --enable=all --platform=unix64 --library=posix.cfg --library=qt.cfg --std=c++17 --inline-suppr $CHECK_CONFIGS"
TV_OPTIONS="$CM_OPTIONS --suppressions-list=$TV_SUPPRESSIONS_LIST --includes-file=$INCLUDES_LIST $TV_IGNORE_DIRS"
PL_OPTIONS="$CM_OPTIONS --suppressions-list=$PL_SUPPRESSIONS_LIST --includes-file=$INCLUDES_LIST_PL $PL_IGNORE_DIRS"

tmpdir=$(mktemp -d /tmp/cppcheck-XXXXXX)

# Perform a configuration check
if [ $opt_c -eq 1 ]; then
    (cd mythtv; cppcheck --check-config $TV_OPTIONS . 2> $tmpdir/cppcheck.config.check.1)
    (cd mythplugins; cppcheck --check-config $PL_OPTIONS . 2> $tmpdir/cppcheck.config.check.2)
    cat $tmpdir/cppcheck.config.check* > $OUTPUT_DIR/cppcheck.config.check
fi

# Build output that emacs can parse
if [ $opt_e -eq 1 ]; then
    (cd mythtv      ; cppcheck --template=gcc $TV_OPTIONS . 2> $tmpdir/cppcheck.emacs.1)
    (cd mythplugins ; cppcheck --template=gcc $PL_OPTIONS . 2> $tmpdir/cppcheck.emacs.2)
    sed -e 's#^[a-z]#mythtv/&#'      $tmpdir/cppcheck.emacs.1 >  $OUTPUT_DIR/cppcheck.emacs
    sed -e 's#^[a-z]#mythplugins/&#' $tmpdir/cppcheck.emacs.2 >> $OUTPUT_DIR/cppcheck.emacs
fi
if [ $opt_x -eq 0 ]; then
    (cd mythtv;      cppcheck --xml-version=2 $TV_OPTIONS . 2> $tmpdir/cppcheck.xml.1)
    (cd mythplugins; cppcheck --xml-version=2 $PL_OPTIONS . 2> $tmpdir/cppcheck.xml.2)
    sed -e 's#file="#file="mythtv/#' \
        -e 's#file0="#file0="mythtv/#' $tmpdir/cppcheck.xml.1 | \
        head -n -2 >  $OUTPUT_DIR/cppcheck.xml
    sed -e 's#file="#file="mythplugins/#' \
        -e 's#file0="#file0="mythplugins/#' $tmpdir/cppcheck.xml.2 | \
        tail -n +5 >> $OUTPUT_DIR/cppcheck.xml
fi

rm -rf $tmpdir
