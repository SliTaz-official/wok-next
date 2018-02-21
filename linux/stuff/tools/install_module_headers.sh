#!/bin/sh
# install_module_headers
# $1 = $install or $install/linux64
src="$2"; KVERSION="$3"

path="usr/src/linux-$KVERSION"

mkdir -p      $1/lib/modules/$KVERSION
ln -sf /$path $1/lib/modules/$KVERSION/build
install -D -m644 $src/Makefile        $1/$path/Makefile
install -D -m644 $src/kernel/Makefile $1/$path/kernel/Makefile
install -D -m644 $src/.config         $1/$path/.config

cp -a $src/include $1/$path

# copy arch includes for external modules
mkdir -p                    $1/$path/arch/x86/
cp -a $src/arch/x86/include $1/$path/arch/x86/

# copy files necessary for later builds, like nvidia and vmware
cp -a $src/Module.symvers $1/$path
cp -a $src/scripts        $1/$path

# fix permissions on scripts dir
chmod og-w -R $1/$path/scripts
mkdir -p      $1/$path/.tmp_versions

mkdir -p                              $1/$path/arch/x86/kernel/
cp $src/arch/x86/Makefile             $1/$path/arch/x86/
cp $src/arch/x86/Makefile_32.cpu      $1/$path/arch/x86/
cp $src/arch/x86/kernel/asm-offsets.s $1/$path/arch/x86/kernel/

# add headers for lirc package
#mkdir -p $1/$path/drivers/media/video
#cp -a $src/drivers/media/video/*.h  $1/$path/drivers/media/video/
#for i in bt8xx cpia2 cx25840 cx88 em28xx et61x251 pwc saa7134 sn9c102 ; do
#	mkdir -p $1/$path/drivers/media/video/$i
#	cp -a $src/drivers/media/video/$i/*.h $1/$path/drivers/media/video/$i
#done

# add docbook makefile
[ -f "$src/Documentation/DocBook/Makefile" ] &&
install -D -m644 $src/Documentation/DocBook/Makefile \
	$1/$path/Documentation/DocBook/Makefile

# add md headers
mkdir -p               $1/$path/drivers/md/
cp $src/drivers/md/*.h $1/$path/drivers/md/

# add inotify.h
mkdir -p                        $1/$path/include/linux/
cp $src/include/linux/inotify.h $1/$path/include/linux/

# add wireless headers
mkdir -p                 $1/$path/net/mac80211/
cp $src/net/mac80211/*.h $1/$path/net/mac80211/

# add dvb headers for external modules
# in reference to http://bugs.archlinux.org/task/9912
mkdir -p                           $1/$path/drivers/media/dvb-core/
cp $src/drivers/media/dvb-core/*.h $1/$path/drivers/media/dvb-core/
# and http://bugs.archlinux.org/task/11194
if [ -d $src/include/config/dvb/ ]; then
	mkdir -p                       $1/$path/include/config/dvb/
	cp $src/include/config/dvb/*.h $1/$path/include/config/dvb/
fi

# add dvb headers for http://mcentral.de/hg/~mrec/em28xx-new
# in reference to http://bugs.archlinux.org/task/13146
mkdir -p                                       $1/$path/drivers/media/dvb-frontends/
cp $src/drivers/media/dvb-frontends/lgdt330x.h $1/$path/drivers/media/dvb-frontends/
mkdir -p                                       $1/$path/drivers/media/i2c/
cp $src/drivers/media/i2c/msp3400-driver.h     $1/$path/drivers/media/i2c/

# add dvb headers
# in reference to http://bugs.archlinux.org/task/20402
mkdir -p                                $1/$path/drivers/media/usb/dvb-usb/
cp $src/drivers/media/usb/dvb-usb/*.h   $1/$path/drivers/media/usb/dvb-usb/
mkdir -p                                $1/$path/drivers/media/dvb-frontends/
cp $src/drivers/media/dvb-frontends/*.h $1/$path/drivers/media/dvb-frontends/
mkdir -p                                $1/$path/drivers/media/tuners/
cp $src/drivers/media/tuners/*.h        $1/$path/drivers/media/tuners/

# add xfs and shmem for aufs building
mkdir -p $1/$path/fs/xfs $1/$path/mm

# copy in Kconfig files
for i in $(find . -name "Kconfig*"); do
	mkdir -p   $1/$path/$(dirname $i)
	cp $src/$i $1/$path/$i
done

# add objtool for external module building and enabled VALIDATION_STACK option
if [ -f $src/tools/objtool/objtool ]; then
	mkdir -p                         $1/$path/tools/objtool/
	cp -a $src/tools/objtool/objtool $1/$path/tools/objtool/
fi

chown -R root.root $1/$path
find $1/$path -type d -exec chmod 755 \{\} \;

# remove unneeded architectures, leave x86 and x86_64
for i in $(ls $1/$path/arch | grep -v x86); do
	rm -rf $1/$path/arch/$i
done
