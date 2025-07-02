vmaccepteula

rootpw VMware1!VMware1!

install --firstdisk --overwritevmfs --ignoreprereqwarnings

network --bootproto=static --ip=192.168.140.101 --netmask=255.255.0.0 --gateway=192.168.0.253 --nameserver=192.168.0.253 --hostname=esxi-host101 --device=vmnic0

reboot

%firstboot --interpreter=busybox

esxcli network ip dns search add --domain=corp.internal

esxcli network ip set --ipv6-enabled=false

vim-cmd hostsvc/enable_ssh
vim-cmd hostsvc/start_ssh

esxcli system ntp set --server=192.168.0.253 --enabled=true

esxcli network vswitch standard add -v vSwitch1
esxcli network vswitch standard add -v vSwitch2

esxcli network vswitch standard set -v vSwitch0 -m 9000
esxcli network vswitch standard set -v vSwitch1 -m 9000
esxcli network vswitch standard set -v vSwitch2 -m 9000

esxcli network vswitch standard uplink add --uplink-name=vmnic1 --vswitch-name=vSwitch0
esxcli network vswitch standard uplink add --uplink-name=vmnic2 --vswitch-name=vSwitch1
esxcli network vswitch standard uplink add --uplink-name=vmnic3 --vswitch-name=vSwitch1
esxcli network vswitch standard uplink add --uplink-name=vmnic4 --vswitch-name=vSwitch2
esxcli network vswitch standard uplink add --uplink-name=vmnic5 --vswitch-name=vSwitch2

esxcli network vswitch standard portgroup add --portgroup-name=vMotion --vswitch-name=vSwitch0
esxcli network vswitch standard portgroup add --portgroup-name=vSAN --vswitch-name=vSwitch0

esxcli network ip netstack add --netstack=vmotion
esxcli network ip interface add --interface-name=vmk1 --portgroup-name=vMotion --netstack=vmotion
esxcli network ip interface add --interface-name=vmk2 --portgroup-name=vSAN

esxcli network ip interface ipv4 set --interface-name=vmk1 --ipv4=192.168.141.101 --netmask=255.255.0.0 --type=static
esxcli network ip interface ipv4 set --interface-name=vmk2 --ipv4=192.168.142.101 --netmask=255.255.0.0 --type=static

for DEV in $(esxcli storage core device list | grep -E '^(naa\.|eui\.|mpx\.|t10\.)'); do
  echo "Marking device as SSD: $DEV" >> /var/log/firstboot-ssd.log
  esxcli storage hpp device set -d $DEV -M true
done

esxcli vsan network ipv4 add -i vmk2
esxcli vsan cluster new --vsanesa

esxcli system syslog config set --loghost='tcp:vrli-l-01a.corp.internal:514'

esxcli system maintenanceMode set -e true

esxcli system shutdown reboot -d 15 -r "Reboot after initial config"
