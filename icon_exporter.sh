#!/bin/sh
#
# Expose directory usage metrics, passed as an argument.
# Usage: add this to crontab:
#
# */5 * * * * prometheus directory-size.sh /var/lib/prometheus | sponge /var/lib/node_exporter/directory_size.prom
#
# sed pattern taken from https://www.robustperception.io/monitoring-directory-sizes-with-the-textfile-collector/
#
#
#ls -la $DATADIR/state/shared_memory.bin | awk ' { print $5 } '

get_memsize()
{
   echo "# HELP ${KRYPT}_total_ram ${KRNAME} Total RAM"
   echo "# TYPE ${KRYPT}_total_ram gauge"
   RAM=$(cat /proc/meminfo |grep MemTotal|awk '{print $2/1024/1024}'); echo "${KRYPT}_total_ram $RAM";
   echo "# HELP ${KRYPT}_size_of_db ${KRNAME} size of statedb database"
   echo "# TYPE ${KRYPT}_size_of_db gauge"
   DBSIZE=$(du -s /mnt/operational/ICONdata/data/ | awk '{print $1}'); DBSIZE=$(echo "scale=2; $DBSIZE / 1048576" | bc); echo "${KRYPT}_size_of_db $DBSIZE";
   echo "# HELP ${KRYPT}_free_space_of_disk ${KRNAME} Free space of disk"
   echo "# TYPE ${KRYPT}_free_space_of_disk gauge"
   FREESPACEDISK=`df | grep $MOUNTP | awk '{print $4}'`; FREESPACEDISK=$(echo "scale=2; $FREESPACEDISK * 1024 / 1073741824" | bc); echo "${KRYPT}_free_space_of_disk $FREESPACEDISK"
} 

get_headblock()
{
   BLOCK=`curl --insecure --connect-timeout 4 --max-time 4 -s -H 'Content-Type: application/json' -d '{"jsonrpc": "2.0", "method": "icx_getLastBlock", "id": 1234}' http://${IPADDR}/api/v3 | awk -F '"height": ' '{print $2}' | awk -F ',' '{print $1}'`
   if [ -z $BLOCK ]; then
      echo "# HELP ${KRYPT}_head_block $KRNAME Head Block"
      echo "# TYPE ${KRYPT}_head_block gauge"
      echo "${KRYPT}_head_block -10"
   else
      echo "# HELP ${KRYPT}_head_block $KRNAME Head Block"
      echo "# TYPE ${KRYPT}_head_block gauge"
      echo "${KRYPT}_head_block $BLOCK"
   fi
}

get_cpu_usage()
{
   NODEPID=`netstat -tlpn 2>/dev/null | grep "0.0.0.0:9000"|awk '{print $4}'`
   if [ -z "$NODEPID" ]; then 
      echo ""
   else
      LOOPCHAINPID=$(ps aux | grep -v grep | grep 'loopchain channel' | awk '{print $2}' | sed 's/ //g');
      GUNICORNPID=$(ps aux | grep -v grep | grep 'gunicorn.*master' | awk '{print $2}' | sed 's/ //g');
      CONFIGUREPID=$(ps aux | grep -v grep | grep 'python \/usr\/local\/bin\/loop.*configure.json' | awk '{print $2}' | sed 's/ //g');
      LOOPCHAINCPU=$(ps -p ${LOOPCHAINPID} -o %cpu | grep -v '%CPU'|sed 's/ //g');
      GUNICORNCPU=$(ps -p ${GUNICORNPID} -o %cpu | grep -v '%CPU'|sed 's/ //g');
      CONFIGURECPU=$(ps -p ${CONFIGUREPID} -o %cpu | grep -v '%CPU'|sed 's/ //g');
      ICONCPU=$(echo "scale=4; $LOOPCHAINCPU + $GUNICORNCPU + $CONFIGURECPU" | bc);
   fi
   
   if [ -z $ICONCPU ]; then
      echo "# HELP ${KRYPT}_cpu_usage $KRNAME Cpu Usage"
      echo "# TYPE ${KRYPT}_cpu_usage gauge"
      echo "${KRYPT}_cpu_usage -10"
   else
      echo "# HELP ${KRYPT}_cpu_usage $KRNAME Cpu Usage"
      echo "# TYPE ${KRYPT}_cpu_usage gauge"
      echo "${KRYPT}_cpu_usage $ICONCPU"
   fi
}

get_mem_usage()
{
   NODEPID=`netstat -tlpn 2>/dev/null | grep "0.0.0.0:9000"|awk '{print $4}'`
   if [ -z "$NODEPID" ]; then
       echo ""
   else
      LOOPCHAINPID=$(ps aux | grep -v grep | grep 'loopchain channel' | awk '{print $2}' | sed 's/ //g')
      GUNICORNPID=$(ps aux | grep -v grep | grep 'gunicorn.*master' | awk '{print $2}' | sed 's/ //g')
      CONFIGUREPID=$(ps aux | grep -v grep | grep 'python \/usr\/local\/bin\/loop.*configure.json' | awk '{print $2}' | sed 's/ //g')
      LOOPCHAINMEM=$(ps -p ${LOOPCHAINPID} -o %mem | grep -v '%MEM'|sed 's/ //g')
      GUNICORNMEM=$(ps -p ${GUNICORNPID} -o %mem | grep -v '%MEM'|sed 's/ //g')
      CONFIGUREMEM=$(ps -p ${CONFIGUREPID} -o %mem | grep -v '%MEM'|sed 's/ //g')
      ICONMEM=$(echo "scale=4; $LOOPCHAINMEM + $GUNICORNMEM + $CONFIGUREMEM" | bc)
   fi

   if [ -z $ICONMEM ]; then
      echo "# HELP ${KRYPT}_mem_usage $KRNAME Mem Usage"
      echo "# TYPE ${KRYPT}_mem_usage gauge"
      echo "${KRYPT}_mem_usage -10"
   else
      echo "# HELP ${KRYPT}_mem_usage $KRNAME Mem Usage"
      echo "# TYPE ${KRYPT}_mem_usage gauge"
      echo "${KRYPT}_mem_usage $ICONMEM"
   fi
}

KRYPT="icon"
KRNAME="ICON"
DATADIR=/mnt/operational/ICONdata
METRICDIR=/var/lib/node_exporter/textfile_collector
MOUNTP="/mnt/operational"
IPADDR="1.1.1.1:9000"

while true; do
   echo "start"
   get_memsize > ${METRICDIR}/icon_metrics.prom
   get_headblock >> ${METRICDIR}/icon_metrics.prom
   get_cpu_usage >> ${METRICDIR}/icon_metrics.prom
   get_mem_usage >> ${METRICDIR}/icon_metrics.prom
   sleep 20;
done

