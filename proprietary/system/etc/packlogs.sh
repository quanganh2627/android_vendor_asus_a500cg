#!/system/bin/sh
# created by ray2_lin@asus.com

# add busybox path for "cut" command by joey_lee@asus.com
PATH="$PATH":/data:/data/debug

# find multiple users in this device by joey_lee@asus.com
cd /data/system/users
multiUsers=$(grep 'user id=' userlist.xml | busybox cut -d '"' -f 2)
echo "multiple users:"
echo  $multiUsers

# find the current user by the last login time by joey_lee@asus.com
currentUser=0
userTime=0
for x in $multiUsers; do
    temp=$(grep 'lastLoggedIn=' "$x.xml" | busybox cut -d '"' -f 10)
    small=$(busybox expr $userTime \< $temp)
    if [ $small -eq 1 ]; then
        userTime=$temp
        currentUser=$x
    fi
done

echo "current user $currentUser with login time $userTime"

FILES=""
# for android 4.2 multiple user by joey_lee@asus.com
#FOLDERS="/data/media/asus_log/ASDF"
FOLDERS="/data/media/$currentUser/asus_log/ASDF"

# logcat & radio
cd /data/logcat_log
for x in logcat logcat-radio logcat-events
do
	stop $x
	mv $x.txt $x.txt.0
	start $x
	FILES+="/data/logcat_log/$x.txt.* "
done

# event log
cd /data/media/asus_log
mv ASUSEvtlog.txt ASUSEvtlog_now.txt


# decide the log file name
PRODUCT=`getprop ro.build.display.id | busybox awk -F "_" '{ print $2}'`
TempVersion=`getprop ro.build.display.id | busybox awk -F "_" '{ print $5}'`
array=($TempVersion)
VERSION=${array[0]};
SKU=`getprop ro.build.asus.sku`
IMEI=`getprop persist.radio.device.imei`
TIME=`date +%y%m%d%H%M%S`
PUG=`getprop persist.asus.logtool.pug`
if [ $PUG ]; then
    if [ $PUG -eq 1 ] || [ $PUG = "1" ]; then
        echo "PUG, replace IMEI"
        random1=$(( $RANDOM % 10 ))
        random2=$(( $RANDOM % 10 ))
        if [ -f "/data/media/$currentUser/ASUS/LogUploader/info.txt" ]; then
            busybox sed -i ''"s/"IMEI=$IMEI"/"IMEI=P$TIME$random1$random2"/g"'' /data/media/$currentUser/ASUS/LogUploader/info.txt
        fi
#        IMEI=P$TIME$random1$random2
#        echo "IMEI=$IMEI"
        PRODUCT=P-$PRODUCT
    fi
fi
REASON=0
if [ $1 ]; then
    REASON=$1
fi
# use product name "A86" for stability by joey_lee@asus.com
# for AT&T special request by joey_lee@asus.com
NEWREASON=$(busybox expr $REASON % 1000)
echo "NEWREASON=$NEWREASON"
OUTFILE=$PRODUCT-$VERSION-$SKU-$IMEI-$TIME-$NEWREASON
#OUTFILE="A91-$VERSION-$SKU-$IMEI-$TIME-$REASON"

SCREENSHOT=`getprop persist.asus.loguploader.pic`
echo "SCREENSHOT=$SCREENSHOT"
if [ -d "/data/media/$currentUser/Screenshots" ] && [ $NEWREASON -ne 0 ] && [ $SCREENSHOT -eq 1 ]; then
    cd /data/media/$currentUser/Screenshots
    screenshot=$(busybox ls -t | busybox head -1)
    echo "screenshot = $screenshot"
    cp $screenshot /data/media/$currentUser/ASUS/LogUploader/$screenshot
    SCREENSHOT=$screenshot
fi

# add meta info file & screenshots
# for android 4.2 multiple user by joey_lee@asus.com
#cd /data/media/ASUS/LogUploader
if [ -d "/data/media/$currentUser/ASUS/LogUploader" ]; then
    cd /data/media/$currentUser/ASUS/LogUploader
    for x in `ls info.txt $SCREENSHOT`; do
        FILES+="$x "
    done
fi

# add extra pictures by joey_lee@asus.com
if [ -d "/data/media/$currentUser/ASUS/LogUploader/ExtraPics" ]; then
    FOLDERS+="/data/media/$currentUser/ASUS/LogUploader/ExtraPics "
fi

# logcat & radio
if [ -d "/data/logcat_log" ]; then
    cd /data/logcat_log
    for x in logcat logcat-radio logcat-events
    do
        stop $x
        mv $x.txt $x.txt.0
        start $x
        FILES+="/data/logcat_log/$x.txt.* "
    done
fi

# event log
if [ -d "/data/media/asus_log" ]; then
    cd /data/media/asus_log
    mv ASUSEvtlog.txt ASUSEvtlog_now.txt
fi

# slow & anr log & modem log
#TIME=`date +%Y-%m-%d-%H-%M`
for x in `ls /data/media/asus_log/ASUSEvtlog_*.txt /data/log/*.txt /data/log/RAMDump?/reason.log`; do
	FILES+="$x "
done

cd /data/media/$currentUser/ASUS/LogUploader

# dumpsys
mkdir -p dumpsys
for x in alarm power battery batterystats; do
	dumpsys $x > dumpsys/$x.txt
	FILES+="dumpsys/$x.txt "
done

# add overheat information by joey_lee@asus.com
mkdir /data/thermal_log
mkdir /data/thermal_log/thermal_zone
mkdir /data/thermal_log/vadc
mkdir /data/thermal_log/etc
if [ -d "/sys/class/thermal" ]; then
    cd /sys/class/thermal
    count=0
    while [ $count -le 10 ]; do
        cp thermal_zone$count/temp /data/thermal_log/thermal_zone/temp$count
        FILES+="/data/thermal_log/thermal_zone/temp$count "
        count=`busybox expr $count + 1`
    done
fi

if [ -d "/dev/thermal/vadc" ]; then
    cd /dev/thermal/vadc
    for x in msm_therm pa_therm0; do
        cp $x /data/thermal_log/vadc/$x
        FILES+="/data/thermal_log/vadc/$x "
    done
fi

cp /proc/driver/BatTemp /data/thermal_log/BatTemp
FILES+="/data/thermal_log/BatTemp "

if [ -d "/etc" ]; then
    cd /etc
    for x in thermal-engine-8974.conf thermald-ultimate-mode.conf thermald-pad.conf; do
        cp $x /data/thermal_log/etc/$x
        FILES+="/data/thermal_log/etc/$x "
    done
fi

# add aab logs by joey_lee@asus.com
mkdir /data/aab_log
cp -r /data/media/$currentUser/ASUS/.aab/* /data/aab_log

cd /data/media/$currentUser/ASUS/LogUploader

ps -t -p -P > ps.txt
FILES+="ps.txt "

# show some info
echo "Packing the following files to $OUTFILE.tar.gz ..."
echo "$FILES"
echo "$FOLDERS"

# start packing logs and delete backuped files
# for android 4.2 multiple user; add email log; add /asdf/* by joey_lee@asus.com
# rename ASUSEvtlog.txt by joey_lee@asus.com
mv /asdf/ASUSEvtlog.txt /asdf/ASUSEvtlog_now.txt
#busybox tar zcf $OUTFILE.tar.gz $FILES $FOLDERS /data/data/com.asus.loguploader/log.txt
busybox tar zcf $OUTFILE.tar.gz $FILES $FOLDERS /data/user/$currentUser/com.asus.loguploader/log.txt /data/media/$currentUser/emaillog.txt /asdf/* /data/aab_log/* /data/anr/* /logs/* /sdcard/Asuslog/* /Removable/MicroSD/Asuslog/* /data/gps/log/*


chown system.system $OUTFILE.tar.gz
chmod 666 $OUTFILE.tar.gz

# for AT&T special request by joey_lee@asus.com
ATT=$(busybox expr $REASON / 1000)
echo "ATT = $ATT"
if [ $ATT -eq 0 ]; then
	# split the output file into 10MB files by joey_lee@asus.com
	# calculate the number of files first
	fileSize=$(busybox stat -c '%s' $OUTFILE.tar.gz)
	fileNum=$(busybox expr $fileSize / 5242880 + 1)
	echo "fileNum = $fileNum"
	busybox split -b 5m $OUTFILE.tar.gz $OUTFILE.tar.gz.$fileNum.
	chown system.system $OUTFILE.tar.gz.$fileNum.*
	chmod 666 $OUTFILE.tar.gz.$fileNum.*
	rm $OUTFILE.tar.gz
fi

rm $FILES
rm -r $FOLDERS
rm -r /data/media/$currentUser/ASUS/LogUploader/ExtraPics
rm -r /data/thermal_log
rm /asdf/ASUSEvtlog*.txt
rm -r /asdf/ASDF/ASDF.*
rm -r /data/aab_log

am broadcast -a "com.asus.packlogs.completed"
 
echo "Done"
 
