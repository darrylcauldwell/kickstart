# Accept the VMware End User License Agreement
vmaccepteula

# Set the root password for the ESXi host
rootpw VMware1!VMware1!

# Install ESXi on the first disk, overwrite any existing VMFS
# the ignore hardware warnings is only necessary due to lab this was created in
install --firstdisk --overwritevmfs --ignoreprereqwarnings

# Configure the management network with a static IP, netmask, gateway, DNS, hostname, and specify the NIC
network --bootproto=static --ip=192.168.140.101 --netmask=255.255.0.0 --gateway=192.168.0.253 --nameserver=192.168.0.253 --hostname=esxi-host101 --device=vmnic0

# Reboot the host after installation is complete
reboot

# Start firstboot section (runs after initial ESXi installation)
%firstboot --interpreter=busybox

# Add a DNS search domain
esxcli network ip dns search add --domain=corp.internal

# Disable IPv6 on the host
esxcli network ip set --ipv6-enabled=false

# Enable and start the SSH service for remote management
vim-cmd hostsvc/enable_ssh
vim-cmd hostsvc/start_ssh

# Configure NTP server and enable NTP service
esxcli system ntp set --server=192.168.0.253 --enabled=true

# Create two additional standard vSwitches (vSwitch1 and vSwitch2)
esxcli network vswitch standard add -v vSwitch1
esxcli network vswitch standard add -v vSwitch2

# Set MTU to 9000 (jumbo frames) on all vSwitches for better network performance
esxcli network vswitch standard set -v vSwitch0 -m 9000
esxcli network vswitch standard set -v vSwitch1 -m 9000
esxcli network vswitch standard set -v vSwitch2 -m 9000

# Add physical NICs (uplinks) to the respective vSwitches for redundancy and bandwidth
esxcli network vswitch standard uplink add --uplink-name=vmnic1 --vswitch-name=vSwitch0
esxcli network vswitch standard uplink add --uplink-name=vmnic2 --vswitch-name=vSwitch1
esxcli network vswitch standard uplink add --uplink-name=vmnic3 --vswitch-name=vSwitch1
esxcli network vswitch standard uplink add --uplink-name=vmnic4 --vswitch-name=vSwitch2
esxcli network vswitch standard uplink add --uplink-name=vmnic5 --vswitch-name=vSwitch2

# Add portgroups for vMotion and vSAN traffic on vSwitch0
esxcli network vswitch standard portgroup add --portgroup-name=vMotion --vswitch-name=vSwitch0
esxcli network vswitch standard portgroup add --portgroup-name=vSAN --vswitch-name=vSwitch0

# Create a dedicated TCP/IP stack for vMotion and add VMkernel interfaces for vMotion and vSAN
esxcli network ip netstack add --netstack=vmotion
esxcli network ip interface add --interface-name=vmk1 --portgroup-name=vMotion --netstack=vmotion
esxcli network ip interface add --interface-name=vmk2 --portgroup-name=vSAN

# Assign static IP addresses to the VMkernel interfaces for vMotion and vSAN
esxcli network ip interface ipv4 set --interface-name=vmk1 --ipv4=192.168.141.101 --netmask=255.255.0.0 --type=static
esxcli network ip interface ipv4 set --interface-name=vmk2 --ipv4=192.168.142.101 --netmask=255.255.0.0 --type=static

# Loop through all storage devices and mark them as SSD for vSAN ESA compatibility
# marking disks as SSDs is only necessary due to the lab this was created in was nested
for DEV in $(esxcli storage core device list | grep -E '^(naa\.|eui\.|mpx\.|t10\.)'); do
  echo "Marking device as SSD: $DEV" >> /var/log/firstboot-ssd.log
  esxcli storage hpp device set -d $DEV -M true
done

# Enable vSAN traffic on the vSAN VMkernel interface
esxcli vsan network ipv4 add -i vmk2

# Create a new vSAN ESA cluster (Express Storage Architecture)
esxcli vsan cluster new --vsanesa

# Configure remote syslog to forward logs to a central log server
esxcli system syslog config set --loghost='tcp:vrli-l-01a.corp.internal:514'

# Place the host into maintenance mode (useful for further automation or scripted changes)
esxcli system maintenanceMode set -e true

# Add UI message
esxcli system welcomemsg set -m="I autoinstalled and pulled my configuration from GitHub!"

# Reboot the host after all initial configuration is complete
esxcli system shutdown reboot -d 15 -r "Reboot after initial config"
