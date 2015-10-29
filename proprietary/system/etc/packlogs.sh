#!/system/bin/sh
# created by ray2_lin@asus.com
# add busybox path for "cut" command by joey_lee@asus.com
PATH="$PATH":/data:/data/debug

# find multiple users in this device by joey_lee@asus.com
cd /data/system/users
multiUsers=$(grep 'user id=' userlist.xml | busybox cut -d '"' -f 2)

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

#Create log file for this script
BugReporterLog="/data/media/$currentUser/ASUS/LogUploader/BugReporterLog.txt"
date > $BugReporterLog
echo "Script Version:1.2 Date:2015/07/14" >> $BugReporterLog
busybox >> $BugReporterLog
chmod 777 $BugReporterLog

echo "current user $currentUser with login time $userTime" >> $BugReporterLog

#FILES will remove when packing done.
FILES=""
#NOTREMOVEFILES won't remove when packing done.
NOTREMOVEFILES=""
#REMOVEFOLDERS will not packing and removing after packing.
REMOVEFOLDERS=""

# decide the log file name
PRODUCT=`getprop ro.product.model | busybox awk '{ sub(/ASUS_/,""); print}'`
VERSION=`getprop ro.build.asus.version`
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
#WARNING: Please do not change REASON and MODEM_CRASH here.
#Split reason and modem crash flag and time.
if [ $1 ]; then
    REASON=`echo $1 | busybox awk -F "_" '{ print $1}'`
    MODEM_CRASH=`echo $1 | busybox awk -F "_" '{ print $2}'`
    TIME=`echo $1 | busybox awk -F "_" '{ print $3}'`
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

if [ -f "/data/media/$currentUser/ASUS/LogUploader/InitAPK.txt" ]; then
   FILES+="InitAPK.txt "
fi

# add extra pictures by joey_lee@asus.com
if [ -d "/data/media/$currentUser/ASUS/LogUploader/ExtraPics" ]; then
    mkdir -p ExtraPics
    cp -rf /data/media/$currentUser/ASUS/LogUploader/ExtraPics/* ExtraPics/

    NOTREMOVEFILES+="ExtraPics/ "
    REMOVEFOLDERS+="/data/media/$currentUser/ASUS/LogUploader/ExtraPics "
    #FILES+="ExtraPics "
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

#add trace log
if [  -e "/sys/class/hwmon/hwmon10/device/trace" ]; then
    cat /sys/class/hwmon/hwmon10/device/trace > /data/media/$currentUser/ASUS/trace
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

patternFilePath="/data/media/$currentUser/ASUS/filtePatternFile.txt"
	#Parse filter pattern file and read first line.
	k=1
	filtePattern=""
	while read line;do
	        if [ $k -eq 1 ]; then
	            filtePattern="$line"
	        fi
	        ((k++))
	done < $patternFilePath
	echo "filter pattern : $filtePattern" >> $BugReporterLog

	#find main log in
	if [ -d "/data/media/$currentUser/Asuslog" ]; then
		mkdir sdcard/ sdcard/Asuslog
		if [ -d "/data/media/$currentUser/Asuslog/Modem" ];then
			COPYDIR=`ls /data/media/$currentUser/Asuslog | busybox sed '/Modem/d'`
		else
			COPYDIR=`ls /data/media/$currentUser/Asuslog`
		fi
		for y in $COPYDIR;do
			cp -r /data/media/$currentUser/Asuslog/$y/ /data/media/$currentUser/ASUS/LogUploader/sdcard/Asuslog/
		done
		FilteFile=`busybox find /data/media/$currentUser/ASUS/LogUploader/sdcard/Asuslog -name Main*.log`
		if [ -f "$patternFilePath" ]; then
		for x in $FilteFile;do
				 if [ -f "$x" ]; then
					 busybox sed -r ''"/"$filtePattern"/d"'' $x > $x.back
					 mv $x.back $x
				 fi
		done
		fi
		  #tar path
		  NOTREMOVEFILES+="sdcard "
		  #remove path
		  REMOVEFOLDERS+="/data/media/$currentUser/ASUS/LogUploader/sdcard "
		  chmod -R 777 /data/media/$currentUser/ASUS/LogUploader/sdcard
	fi
	#If MicroSD Card has data find main log
	if [ -d "/Removable/MicroSD/Asuslog" ]; then
		mkdir -p Removable/MicroSD Removable/MicroSD/Asuslog
		if [ -d "/Removable/MicroSD/Asuslog/Modem" ];then
			COPYDIR_SD=`ls /Removable/MicroSD/Asuslog | busybox sed '/Modem/d'`
		else
			COPYDIR_SD=`ls /Removable/MicroSD/Asuslog`
		fi
		for z in $COPYDIR_SD;do
			cp -r /Removable/MicroSD/Asuslog/$z/ /data/media/$currentUser/ASUS/LogUploader/Removable/MicroSD/Asuslog/
		done
		FilteFile=`busybox find /data/media/$currentUser/ASUS/LogUploader/Removable/MicroSD/Asuslog -name Main*.log`
		if [ -f "$patternFilePath" ]; then
			for x in $FilteFile;do
					 if [ -f "$x" ]; then
						 busybox sed -r ''"/"$filtePattern"/d"'' $x > $x.back
						 mv $x.back $x
					 fi
			done
		fi
		NOTREMOVEFILES+="Removable "
		REMOVEFOLDERS+="/data/media/$currentUser/ASUS/LogUploader/Removable "
		chmod -R 777 /data/media/$currentUser/ASUS/LogUploader/Removable
	fi
#Pack modem crash log feature
if [ $MODEM_CRASH -eq 1 ];then
	#find out modem path, both sdcard and MicroSDcard
	if [ -d /data/media/$currentUser/Asuslog/ ]; then
		MODEM_PATH=`busybox find /data/media/$currentUser/Asuslog/ -name Modem*`
	fi
	if [ -d /Removable/MicroSD/Asuslog ]; then
		MODEM_PATH+=" `busybox find /Removable/MicroSD/Asuslog/ -name Modem*`"
	fi
	echo "Modem path is $MODEM_PATH" >> $BugReporterLog
	for x in $MODEM_PATH;do
		#Check modem crash status, if crash find out lastest 3 files
		if [ -d $x ];then
			MODEM_FILE_NUM=`ls -al $x/*.istp | busybox wc -l`
			MODEM_NAME=`echo $x | busybox sed 's#/#\ #g' | busybox awk '{print $5}'`
			CHECK_MICRO_SD_PATH=`echo $x | busybox sed 's#/#\ #g' | busybox awk '{print $1}'`
			echo "$x modem file is $MODEM_FILE_NUM"
			echo "Modem name is $MODEM_NAME"
			#Check file number if bigger than 3, keep latest 3.
			if [ $MODEM_FILE_NUM -gt 3 ];then
				RMNUM=`busybox expr $MODEM_FILE_NUM - 3`
				REMOVE_FILE_NAME=`ls -al $x/*.istp | busybox sort -k 7 | busybox head -n $RMNUM | busybox awk '{print $7}'`
				echo "Num:$RMNUM REMOVE_FILE_NAME are $REMOVE_FILE_NAME"
				for REMOVE_MODEM_FILE in $REMOVE_FILE_NAME;do
					rm $x/$REMOVE_MODEM_FILE
				done
			fi
			DIR_NAME=""
			if [ $CHECK_MICRO_SD_PATH = Removable ];then
				echo "MircroSD card modem, replace file name"
				DIR_NAME=MicroSD/
				mkdir /data/media/$currentUser/ASUS/LogUploader/$DIR_NAME
			fi
			cp -r $x /data/media/$currentUser/ASUS/LogUploader/$DIR_NAME
			chmod 777 /data/media/$currentUser/ASUS/LogUploader/$DIR_NAME
			MODEM_TAR_FILE+="$MODEM_NAME "
		fi
	done
#Pack Modem log
MODEM_TAR_FILE+="MicroSD/ "
busybox tar zcf Modem_log.tar.gz $MODEM_TAR_FILE
FILES+="Modem_log.tar.gz "
fi
# start packing logs and delete backuped files
# for android 4.2 multiple user; add email log; add /asdf/* by joey_lee@asus.com
# rename ASUSEvtlog.txt by joey_lee@asus.com
mv /asdf/ASUSEvtlog.txt /asdf/ASUSEvtlog_now.txt
#For crash logs in sdcard (emmc)
cp -r /data/media/$currentUser/logs/ /data/media/$currentUser/ASUS/LogUploader/
cp -r /data/logs/* /data/media/$currentUser/ASUS/LogUploader/logs/
FILES+="logs "

NOTREMOVEFILES+="/data/user/$currentUser/com.asus.loguploader/log.txt /data/media/$currentUser/emaillog.txt /asdf/* /data/aab_log/* /data/media/$currentUser/ASUS/trace /data/anr/* $BugReporterLog "

# show some info
echo "tar file name : $OUTFILE.tar.gz" >> $BugReporterLog
echo "tar files : $FILES" >> $BugReporterLog
echo "tar files not remove : $NOTREMOVEFILES" >> $BugReporterLog

busybox tar zcf $OUTFILE.tar.gz $FILES $NOTREMOVEFILES
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

rm -rf $FILES
rm -rf $REMOVEFOLDERS
rm -rf $MODEM_TAR_FILE
rm -r /data/thermal_log
rm /asdf/ASUSEvtlog*.txt
rm -r /asdf/ASDF/ASDF.*
rm -r /data/aab_log


#echo "Broadcast return : " >> $BugReporterLog
#am broadcast -a "com.asus.packlogs.completed" >> $BugReporterLog

echo "Done" >> $BugReporterLog
date >> $BugReporterLog
