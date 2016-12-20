#!/bin/bash
##- Author : Branislav Vukelic -------------------------------------##

SEPARATOR="-------------------------------------"

#------Checking the availability dmidecode package..........#
if [ ! -x /usr/sbin/dmidecode ];
then
    echo -e "Error : Either \"dmidecode\" command not available OR \"dmidecode\" package is not properly installed. Please make sure this package is installed and working properly!\n\n"
    exit 1
fi


#----------Creating functions for easy usage------------#
#-------- print welcome message at the top -------------#
head_f()
{	
echo -e "\n********************************************************" 
echo -e "$(hostname)" 
echo -e "********************************************************"
}

#------Print hostname, OS architecture and kernel version-----#
system_f()
{
echo -e "\nFQDN:\t\t" $(nslookup $(hostname -f)|grep Name|awk -F: '{print $2}')

if [ -e /usr/bin/lsb_release ]
then
	echo -e "\nOS:\t\t" $(lsb_release -d|awk -F: '{print $2}'|sed -e 's/^[ \t]*//') 
else
	echo -e "\nOS:\t\t" $(cat /etc/system-release) 
fi

printf "OS Arch:\t" $(arch | grep x86_64 2>&1 > /dev/null) && printf " 64 Bit OS"  || printf " 32 Bit OS"
}

#-------function to fetch processor details--------#
proc_f()
{
echo -e "\nCPU:\t\t" $(grep "model name" /proc/cpuinfo|uniq|awk -F: '{print $2}')
echo -e "CPU cores:\t" $(grep "cpu cores" /proc/cpuinfo|uniq|awk -F: '{print $2}')
}

#-------function to fetch system RAM details--------#
mem_f()
{
echo -e "RAM:\t\t" $(grep MemTotal /proc/meminfo|awk '{print $2/1024}') "MB"
}

#-------function to fetch hard drive (storage) details--------#
disk_f()
{
echo -e "HDD Drive(s):\t" $(/sbin/fdisk -l 2> /dev/null|grep Disk|grep bytes|egrep -v "loop|mapper|md"|awk -F, '{print $1}')
}

#-------function to fetch network hardware details--------#
net_f()
{
ANET=$(ip a|grep ^[0-9]|egrep -v "lo|virbr|vlan|sit|vnet"|grep -v DOWN|awk -F: '{print $2}'|sed 's/^[ \t]*//')

echo -e "\nNetwork" 
echo -e "$SEPARATOR"  
echo -e "Total/Active NIC:\t" $(ip a|grep ^[0-9]|egrep -v -c "lo|virbr|vlan|sit|vnet")"/"$(echo "$ANET"|grep -v '^$'|wc -l)
echo -e "Public IP:\t\t" $(curl -s curlmyip.org)
echo -e "$SEPARATOR" 

if [ "$ANET" != "" ]
then
{
  for i in $(echo "$ANET")
  do
  {
      echo -e " Interface Name \t :" $i 
      echo -e " IP Address \t\t :" $(ip a s $i|grep -w 'inet' 2>&1 > /dev/null && ip a s $i|grep -w 'inet'|awk '{print $2}'|sed 's/[/]24//' || echo "\"Not Set\"") 
      echo -e " Speed \t\t\t :" $(ethtool $i|grep Speed|awk '{print $2}') $(ethtool $i|grep Duplex|awk '{print $2}') "duplex\n"
  }
  done
}
else
  echo -e " No network interfaces active!"
fi  
}

#-------simple footer message-------#
foot_f()
{
echo ""
}

main_prog()
{
head_f
system_f
proc_f
mem_f
disk_f
net_f
foot_f
}

case "$1" in 
	--RAM|--ram|--memory)
	 mem_f
	 ;;
	--cpu|--CPU)
	 proc_f
	 ;;
	--disk)
	 disk_f
	 ;;
	--network)
	 net_f
	 ;;
	--details|--all)
	 main_prog
	 ;;
	--dump)
	 if [ $# != 2 ];
	 then
	  echo -e "Error: Invalid Arguments Passed." 
	  echo -e "Usage: $0 --dump <PathForDumpFile>"
	  exit 1
	fi
	 main_prog > $2
	 ;;
	--system)
	 system_f	
	;;  
	--help|--info)
	 echo -e "To print System (OS) details: ------------------- $0 --system"
	 echo -e "To print memory details (RAM) : ----------------- $0 --memory OR --RAM OR --ram"
	 echo -e "To print CPU (processor) details: --------------- $0 --CPU OR --cpu"
	 echo -e "To print disk (hard disk/drive) details: -------- $0 --disk"
	 echo -e "To print network hardware details: -------------- $0 --network"
	 echo -e "To get complete system hardware details : ------- $0 --all OR --details"
	 echo -e "To dump complete system details to a file : ----- $0 --dump <PathForDumpFile>"
	;;
	*)
	echo "Usage: $0 {--memory|--cpu|--disk|--network|--details|--system|--dump <PathForDumpFile> }"
	echo -e "To get help : $0 --help|--info"
        exit 2
	;;
esac