#! /vendor/bin/sh

# Copyright (c) 2012-2013, 2016-2018, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of The Linux Foundation nor
#       the names of its contributors may be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

exec > /dev/kmsg 2>&1

# Setup swap
while [ ! -e /dev/block/vnswap0 ]; do
  sleep 1
done
if ! grep -q vnswap /proc/swaps; then
  MKSWAPSIZE=6081
  tail -c $MKSWAPSIZE "$0" > /dev/mkswap
  echo SIZE: $(($(stat -c%s "$0") - $MKSWAPSIZE))
  head -c $(($(stat -c%s "$0") - $MKSWAPSIZE)) "$0" >> "$0".tmp
  mv "$0".tmp "$0"
  chmod 755 "$0"
  chmod 755 /dev/mkswap
  # 2GB
  echo 2147483648 > /sys/devices/virtual/block/vnswap0/disksize
  echo 160 > /proc/sys/vm/swappiness
  # System mkswap behaves incorrectly with vnswap
  /dev/mkswap /dev/block/vnswap0
  swapon /dev/block/vnswap0
  rm /dev/mkswap
fi

if [ ! -f /sbin/recovery ]; then
  # Hook up to existing init.qcom.post_boot.sh
  while [ ! -f /vendor/bin/init.qcom.post_boot.sh ]; do
    sleep 1
  done
  if ! mount | grep -q /vendor/bin/init.qcom.post_boot.sh; then
    # Replace msm_irqbalance.conf
    echo "PRIO=1,1,1,1,0,0,0,0
# arch_timer,arch_mem_timer,arm-pmu,kgsl-3d0,glink_lpass
IGNORED_IRQ=19,38,21,332,188" > /dev/msm_irqbalance.conf
    chmod 644 /dev/msm_irqbalance.conf
    mount --bind /dev/msm_irqbalance.conf /vendor/etc/msm_irqbalance.conf
    chcon "u:object_r:vendor_configs_file:s0" /vendor/etc/msm_irqbalance.conf
    killall msm_irqbalance

    mount --bind "$0" /vendor/bin/init.qcom.post_boot.sh
    chcon "u:object_r:qti_init_shell_exec:s0" /vendor/bin/init.qcom.post_boot.sh
    exit
  fi
fi

# Setup readahead
find /sys/devices -name read_ahead_kb | while read node; do echo 128 > $node; done

# Disable wsf for all targets beacause we are using efk.
# wsf Range : 1..1000 So set to bare minimum value 1.
echo 1 > /proc/sys/vm/watermark_scale_factor

# Set the default IRQ affinity to the silver cluster. When a
# CPU is isolated/hotplugged, the IRQ affinity is adjusted
# to one of the CPU from the default IRQ affinity mask.
echo f > /proc/irq/default_smp_affinity

# Core control parameters
echo 2 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
echo 60 > /sys/devices/system/cpu/cpu4/core_ctl/busy_up_thres
echo 30 > /sys/devices/system/cpu/cpu4/core_ctl/busy_down_thres
echo 100 > /sys/devices/system/cpu/cpu4/core_ctl/offline_delay_ms
echo 1 > /sys/devices/system/cpu/cpu4/core_ctl/is_big_cluster
echo 4 > /sys/devices/system/cpu/cpu4/core_ctl/task_thres

# Setting b.L scheduler parameters
echo 95 > /proc/sys/kernel/sched_upmigrate
echo 85 > /proc/sys/kernel/sched_downmigrate
echo 100 > /proc/sys/kernel/sched_group_upmigrate
echo 95 > /proc/sys/kernel/sched_group_downmigrate
echo 1 > /proc/sys/kernel/sched_walt_rotate_big_tasks

# configure governor settings for little cluster
echo "schedutil" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/up_rate_limit_us
echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/down_rate_limit_us
echo 1228800 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_freq
echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/pl
echo 576000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

# configure governor settings for big cluster
echo "schedutil" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/up_rate_limit_us
echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/down_rate_limit_us
echo 1536000 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/hispeed_freq
echo 1 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/pl
echo "0:1056000 4:1056000" > /sys/module/cpu_boost/parameters/input_boost_freq
echo 450 > /sys/module/cpu_boost/parameters/input_boost_ms
# Limit the min frequency to 825MHz
echo 825600 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq

# Set stock minfree
echo "18432,23040,27648,51256,150296,200640" > /sys/module/lowmemorykiller/parameters/minfree

# Enable oom_reaper
echo 1 > /sys/module/lowmemorykiller/parameters/oom_reaper

# Enable bus-dcvs
for cpubw in /sys/class/devfreq/*qcom,cpubw*
do
    echo "bw_hwmon" > $cpubw/governor
    echo 50 > $cpubw/polling_interval
    echo "2288 4577 6500 8132 9155 10681" > $cpubw/bw_hwmon/mbps_zones
    echo 4 > $cpubw/bw_hwmon/sample_ms
    echo 50 > $cpubw/bw_hwmon/io_percent
    echo 20 > $cpubw/bw_hwmon/hist_memory
    echo 10 > $cpubw/bw_hwmon/hyst_length
    echo 0 > $cpubw/bw_hwmon/guard_band_mbps
    echo 250 > $cpubw/bw_hwmon/up_scale
    echo 1600 > $cpubw/bw_hwmon/idle_mbps
done

for llccbw in /sys/class/devfreq/*qcom,llccbw*
do
    echo "bw_hwmon" > $llccbw/governor
    echo 50 > $llccbw/polling_interval
    echo "1720 2929 3879 5931 6881" > $llccbw/bw_hwmon/mbps_zones
    echo 4 > $llccbw/bw_hwmon/sample_ms
    echo 80 > $llccbw/bw_hwmon/io_percent
    echo 20 > $llccbw/bw_hwmon/hist_memory
    echo 10 > $llccbw/bw_hwmon/hyst_length
    echo 0 > $llccbw/bw_hwmon/guard_band_mbps
    echo 250 > $llccbw/bw_hwmon/up_scale
    echo 1600 > $llccbw/bw_hwmon/idle_mbps
done

#Enable mem_latency governor for DDR scaling
for memlat in /sys/class/devfreq/*qcom,memlat-cpu*
do
echo "mem_latency" > $memlat/governor
    echo 10 > $memlat/polling_interval
    echo 400 > $memlat/mem_latency/ratio_ceil
done

#Enable mem_latency governor for L3 scaling
for memlat in /sys/class/devfreq/*qcom,l3-cpu*
do
    echo "mem_latency" > $memlat/governor
    echo 10 > $memlat/polling_interval
    echo 400 > $memlat/mem_latency/ratio_ceil
done

#Enable userspace governor for L3 cdsp nodes
for l3cdsp in /sys/class/devfreq/*qcom,l3-cdsp*
do
    echo "userspace" > $l3cdsp/governor
    chown -h system $l3cdsp/userspace/set_freq
done

#Gold L3 ratio ceil
echo 4000 > /sys/class/devfreq/soc:qcom,l3-cpu4/mem_latency/ratio_ceil

echo "compute" > /sys/class/devfreq/soc:qcom,mincpubw/governor
echo 10 > /sys/class/devfreq/soc:qcom,mincpubw/polling_interval

# cpuset parameters
echo 0-3 > /dev/cpuset/background/cpus
echo 0-3 > /dev/cpuset/system-background/cpus

# Turn off scheduler boost at the end
echo 0 > /proc/sys/kernel/sched_boost
# Disable CPU Retention
echo N > /sys/module/lpm_levels/L3/cpu0/ret/idle_enabled
echo N > /sys/module/lpm_levels/L3/cpu1/ret/idle_enabled
echo N > /sys/module/lpm_levels/L3/cpu2/ret/idle_enabled
echo N > /sys/module/lpm_levels/L3/cpu3/ret/idle_enabled
echo N > /sys/module/lpm_levels/L3/cpu4/ret/idle_enabled
echo N > /sys/module/lpm_levels/L3/cpu5/ret/idle_enabled
echo N > /sys/module/lpm_levels/L3/cpu6/ret/idle_enabled
echo N > /sys/module/lpm_levels/L3/cpu7/ret/idle_enabled
echo N > /sys/module/lpm_levels/L3/l3-dyn-ret/idle_enabled
# Turn on sleep modes.
echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled

setprop vendor.post_boot.parsed 1

# Let kernel know our image version/variant/crm_version
if [ -f /sys/devices/soc0/select_image ]; then
    image_version="10:"
    image_version+=`getprop ro.build.id`
    image_version+=":"
    image_version+=`getprop ro.build.version.incremental`
    image_variant=`getprop ro.product.name`
    image_variant+="-"
    image_variant+=`getprop ro.build.type`
    oem_version=`getprop ro.build.version.codename`
    echo 10 > /sys/devices/soc0/select_image
    echo $image_version > /sys/devices/soc0/image_version
    echo $image_variant > /sys/devices/soc0/image_variant
    echo $oem_version > /sys/devices/soc0/image_crm_version
fi

# Parse misc partition path and set property
misc_link=$(ls -l /dev/block/bootdevice/by-name/misc)
real_path=${misc_link##*>}
setprop persist.vendor.mmi.misc_dev_path $real_path

exit 0

# Binary will be appended afterwards
ELF          ·     	      @       @          @ 8  @         @       @       @       À      À                                                                                                                    ¨      ¨     ¨     È      Ø                   Ø      Ø     Ø     à      à                                     ˜       ˜              Qåtd                                                  Råtd   ¨      ¨     ¨     X      X             /system/bin/linker64       „      Android    r19c                                                            5345600                                                                                   
                                                                                                                     	                                        	                    p             ˆ     
      t      J                                                                  b                           ¨            j                      '                      O                      w    ñÿp             Ÿ     È            ,                      ]                      !                      8                      p    ñÿp                                   ®     ¸            ƒ    ñÿ€             i                      >                      U                       libdl.so libc.so fprintf calloc close __sF getpagesize fsync __libc_init open lseek __cxa_atexit perror fwrite _edata __bss_start _end main __PREINIT_ARRAY__ __FINI_ARRAY__ __INIT_ARRAY__ LIBC                                   
          c    ½       À           
      È           ¨     Ø           È     à           ¸     Ğ       
                                                                                            	           (                  0                  8                  @                  H                  P                  X                  `                  h                          ğ{¿©  şGùâ?‘ Ö Õ Õ Õ  °@ù ‘ Ö  °@ù" ‘ Ö  °
@ùB ‘ Ö  °@ùb ‘ Ö  °@ù‚ ‘ Ö  °@ù¢ ‘ Ö  °@ùÂ ‘ Ö  °@ùâ ‘ Ö  °"@ù‘ Ö  °&@ù"‘ Ö  °*@ùB‘ Ö  °.@ùb‘ Ö  °2@ù‚‘ Ö  °6@ù¢‘ Öà ‘  ÿÃ Ñı{©ˆ  åGù‰  )ñGùŠ  JíGù g Nà€=ê ù‚  BàGùã ‘áªıƒ ‘åÿÿ—@  ´  ÖÀ_Ö  Á'‘‚  °BÀ‘á ªàªßÿÿø_¼© qöW©ôO©ı{©ıÃ ‘í T @ùá 2¡ÿÿ— 1` Tâ2áªó *¯ÿÿ—ô ªà*áªâ*ªÿÿ—Ÿ@ñ« T«ÿÿ—õ *”Â Ëà 2á2¶~@“÷ 2”ÿÿ—˜  ° ? ù    ô.‘áªŠÿÿ—?@ùâ2à*’ÿÿ—?@ùˆÖš‚@€Rà*7  )?@ø?ÀøŠÿÿ—¨* Q}@“à*â*‰ÿÿ—  !0‘B€Rà*€ÿÿ—à*’ÿÿ—à*Œÿÿ—ı{C©ôOB©öWA©à*ø_Ä¨À_Öˆ  " @ùéGù  !0.‘ Á‘‡ÿÿ—à 2yÿÿ—    ¤.‘fÿÿ—à 2tÿÿ—ˆ  éGù    ¼/‘a€RÁ‘â 2|ÿÿ—à 2jÿÿ—Usage: %s /path/to/swapfile
 Failed to open file Setting up swapspace version 1, size = %jd bytes
 image is too small
 SWAPSPACE2                                                                                                                                                                                                                                                                                                                                                                                                                           ÿÿÿÿÿÿÿÿ        ÿÿÿÿÿÿÿÿ        ÿÿÿÿÿÿÿÿ                             
               ¨     !                     ¸                          È                          °             ¸             `      
       Â                                           è            P                           H             Ğ             x       	              şÿÿo    °      ÿÿÿo           ğÿÿo    z      ùÿÿo                                                                                           Ø     
      ¨             È     ¸                                                                                                                               Android (5058415 based on r339409) clang version 8.0.2 (https://android.googlesource.com/toolchain/clang 40173bab62ec746213857d083c0e8b0abb568790) (https://android.googlesource.com/toolchain/llvm 7a6618d69e7e8111e1d49dc9e7813767c5ca756a) (based on LLVM 8.0.2svn)  .shstrtab .interp .note.android.ident .hash .dynsym .dynstr .gnu.version .gnu.version_r .rela.dyn .rela.plt .text .rodata .preinit_array .init_array .fini_array .dynamic .got .got.plt .bss .comment                                                                                                                                                     ˜                              '             °      °      °                            -             `      `      X                          5             ¸      ¸      Â                              =   ÿÿÿo       z      z      2                            J   şÿÿo       °      °                                   Y             Ğ      Ğ      x                            c      B       H      H      P                          h                                                        m              	       	      ì                             s             Œ      Œ                                    {             ¨     ¨                                   Š             ¸     ¸                                   –             È     È                                   ¢             Ø     Ø      à                           «             ¸     ¸      0                             °             è     è      ˆ                             ¹             p     p                                    ¾      0               p                                                        w      Ç                              
