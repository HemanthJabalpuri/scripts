#!/system/bin/sh
mount -o remount,rw /system
min=1
max=5
number=0
while [ "$number" -lt $min ]
do
  number=$RANDOM
  let "number %= $max"
done
cd /system/media
mv bootanimation.zip bootanimation.temp
mv bootanimation${number}.zip bootanimation.zip
mv bootanimation.temp bootanimation${number}.zip
chmod 644 bootanimation.zip
mount -o remount,ro /system

# for this you need to place 4 bootanimations with names
# bootanimation1.zip
# bootanimation2.zip
# bootanimation3.zip
# bootanimation4.zip
# in /system/media

# You can also do this by using ROM Toolbox...

# For now you have 5 bootanimation...
# If you want more then place extra bootanimation.zip's then change max according to your preference and those file names in the format bootanimation{max-1}.zip as last bootanimation...
