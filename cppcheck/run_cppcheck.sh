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

CHECK_CONFIGS="-DBETTERCOMPRESSION -DBigEndian_ -D__BIG_ENDIAN__ -DBSD -DCOLOR_BGRA -DCOMPILE_3DNOW -DCOMPILE_MMX -DCOMPILE_MMX2 -DCOMPILE_SSE -D__cplusplus -DDCRAW_SUPPORT -DEXIF_SUPPORT -DFFTW3_SUPPORT -DGL_ES_VERSION_2_0 -D__GNUC__ -DHAS_DIR -DHAVE_3DNOW -DHAVE_ATHLON -DHAVE_CDAUDIO -DHAVE_CONFIG_H -DHAVE_MMX -DHAVE_MMX2 -DHAVE_ONLY_MMX1 -DHAVE_SSE -DHAVE_STDINT_H -DICC_PROFILE -D_IMPLEMENT_VERBOSE -DINSTALL_ROOT -DIP_MULTICAST_IF -DIS_SSE -DLAME_WORKAROUND -DLATER -Dlinux -D__linux__ -DLZO1Y -DMETA_API -DMINILZO_HAVE_CONFIG_H -Dmm_flags -DMMX -DMMXBLAH -DMODE_ifs -D_MSC_VER -DMUI_API -DMYTH_BUILD_CONFIG -DNO_ERRNO_H -DNO_MYTH -DNVIDIA_6629 -D__OpenBSD__ -DOPENGL_SUPPORT -DPA_MAJOR -DPGM_CONVERT_GREYSCALE -D_POSIX_PRIORITY_SCHEDULING -DPOWERPC -DPROTOSERVER_API -DQ_OS_MAC -DQ_OS_MACX -DQT_MAC_USE_COCOA -DQWS -DQ_WS_MACX -DQ_WS_MACX_OLDQT -DSDL_SUPPORT -DSERVICE_API -DSHOWBLOCK -DSIGBUS -DSNDCTL_DSP_GETODELAY -DSPEW_FILES -DSTANDALONE -DSTATISTIC -DSTDC -DSTRICT_COMPAT -DTF_TSC_TICKS -DTF_TYPE_TSC -DTIME_FILTER -DUPNP_API -DUSE_ALSA -DUSE_ASM -DUSE_JACK -DUSE_JOYSTICK_MENU -DUSE_LIRC -DUSE_MODULES -DUSE_MOUNT_COMMAND -DUSE_OPENGL_PAINTER -DUSE_SETSOCKOPT -DUSING_ALSA -DUSING_APPLEREMOTE -DUSING_ASI -DUSING_BACKEND -DUSING_CRYSTALHD -DUSING_DARWIN_DA -DUSING_DVB -DUSING_DXVA2 -DUSING_FFMPEG_THREADS -DUSING_FIREWIRE -DUSING_HDHOMERUN -DUSING_HDPVR -DUSING_IPTV -DUSING_IVTV -DUSING_JACK -DUSING_LIBASS -DUSING_LIBUDF -DUSING_LINUX_FIREWIRE -DUSING_MHEG -DUSING_MINGW -DUSING_OPENGL -DUSING_OPENGLES -DUSING_OPENGL_VIDEO -DUSING_OSS -DUSING_OSX_FIREWIRE -DUSING_PULSE -DUSING_PULSEOUTPUT -DUSING_QUARTZ_VIDEO -DUSING_V4L1 -DUSING_V4L2 -DUSING_VAAPI -DUSING_VALGRIND -DUSING_VDPAU -DUSING_X11 -DUSING_XRANDR -DUSING_XV -DV4L2_CAP_SLICED_VBI_CAPTURE -DVDP_DECODER_PROFILE_MPEG4_PART2_ASP -D_WIN32 -DUSING_CETON -DCONFIG_QTDBUS"
HTML_FILE="index.html"

# Switch to the source directory to get relative paths in output
#cd $SOURCE_DIR

CM_OPTIONS="$QUIET -j$JOBS_LIMIT --enable=all --platform=unix64 --library=posix.cfg --library=qt.cfg --std=posix --std=c++11 --std=c99 --inline-suppr $CHECK_CONFIGS"
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
    sed -e 's#file="#file="mythplugin/#' \
        -e 's#file0="#file0="mythplugin/#' $tmpdir/cppcheck.xml.2 | \
        tail -n +5 >> $OUTPUT_DIR/cppcheck.xml
fi

rm -rf $tmpdir
