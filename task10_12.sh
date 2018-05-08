\#!/bin/bash

d=`dirname $0`
cd $d

#доп параметры
. "$d/config"

#обновления и доп пакеты
apt update -yq
apt-get install libvirt-bin -yq
apt-get install qemu-kvm -yq
#Доп параметры
MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`
mkdir networks
mkdir config-drives
mkdir config-drives/$VM1_NAME-config
mkdir config-drives/$VM2_NAME-config
mkdir /var/lib/libvirt/images/vm1
mkdir /var/lib/libvirt/images/vm2
#Загрузка образа
VMs_qcow2=/var/lib/libvirt/images/ubuntu-server-16.04.qcow2
wget -O /var/lib/libvirt/images/ubuntu-server-16.04.qcow2 $VM_BASE_IMAGE
#xml для external network

echo "<network>
  <name>$EXTERNAL_NET_NAME</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <ip address='192.168.123.1' netmask='$EXTERNAL_NET_MASK'>
    <dhcp>
      <range start='$EXTERNAL_NET.2' end='$EXTERNAL_NET.254'/>
      <host mac='$MAC' name='vm1' ip='$VM1_EXTERNAL_IP'/>
    </dhcp>
  </ip>
</network>" >  networks/$EXTERNAL_NET_NAME.xml

#xml для internal network
echo "<network>
         <name>$INTERNAL_NET_NAME</name>
         <ip address='$INTERNAL_NET_IP' netmask='$INTERNAL_NET_MASK'/>
</network>" > networks/$INTERNAL_NET_NAME.xml

#xml для management
echo "<network>
         <name>$MANAGEMENT_NET_NAME</name>
         <ip address='$MANAGEMENT_NET_IP' mask='$MANAGEMENT_NET_MASK'/>
</network>" > networks/$MANAGEMENT_NET_NAME.xml



#добавления виртуальных сетей 
virsh net-define networks/$EXTERNAL_NET_NAME.xml
virsh net-define networks/$INTERNAL_NET_NAME.xml
virsh net-define networks/$MANAGEMENT_NET_NAME.xml

virsh net-start $EXTERNAL_NET_NAME
virsh net-start $INTERNAL_NET_NAME
virsh net-start $MANAGEMENT_NET_NAME


#конфиг ВМ1

echo "<domain type='$VM_VIRT_TYPE'>
  <name>$VM1_NAME</name>
  <memory unit='MiB'>$VM1_MB_RAM</memory>
  <vcpu placment='static'>$VM1_NUM_CPU</vcpu>
  <os>
    <type>$VM_TYPE</type>
    <boot dev='hd'/>
  </os>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='$VM1_HDD'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='$VM1_CONFIG_ISO'/>
      <target dev='hdc' bus='ide'/>
      <readonly/>
    </disk>
    <interface type='network'>
      <source dev='$VM1_EXTERNAL_IF'/>
      <mac address='$MAC'/>
      <source network='$EXTERNAL_NET_NAME'/>
      <model type='virtio'/>
    </interface>
    <interface type='network'>
      <source dev='$VM1_INTERNAL_IF'/>
      <mac address='$MAC'/>
      <source network='$INTERNAL_NET_NAME'/>
      <model type='virtio'/>
    </interface>
    <interface type='network'>
      <source dev='$VM1_MANAGEMENT_IF'/>
      <mac address='$MAC'/>
      <source network='$MANAGEMENT_NET_NAME'/>
      <model type='virtio'/>
    </interface>
  </devices>
</domain>" > $VM1_NAME.xml




#конфиг ВМ2


echo "<domain type='$VM_VIRT_TYPE'>
  <name>$VM2_NAME</name>
  <memory unit='MiB'>$VM2_MB_RAM</memory>
  <vcpu placment='static'>$VM2_NUM_CPU</vcpu>
  <os>
    <type>$VM_TYPE</type>
    <boot dev='hd'/>
  </os>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='$VM2_HDD'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='$VM2_CONFIG_ISO'/>
      <target dev='hdc' bus='ide'/>
      <readonly/>
    </disk>
    <interface type='network'>
      <source dev='$VM2_INTERNAL_IF'>
      <mac address='$MAC'/>
      <source network='$INTERNAL_NET_NAME'/>
      <model type='virtio'/>
    </interface>
    <interface type='network'>
      <source dev='$VM2_MANAGEMENT_IF'/>
      <mac address='$MAC'/>
      <source network='$MANAGEMENT_NET_NAME'/>
      <model type='virtio'/>
    </interface>
  </devices>
</domain>" > $VM2_NAME.xml

#meta-data vm1
echo "instance-id: vm1-toljika
hostname: $VM1_NAME
local-hostname: $VM1_NAME
network-interfaces: |
  auto $VM1_EXTERNAL_IF
  iface $VM1_EXTERNAL_IF inet dhcp

  auto $VM1_INTERNAL_IF
  iface $VM1_INTERNAL_IF inet static
  address $VM1_INTERNAL_IP
  network $INTERNAL_NET_IP
  netmask $INTERNAL_NET_MASK
  broadcast $INTERNAL_NET.254
  dns $VM_DNS

  auto $VM1_MANAGEMENT_IF 
  ifcae $VM1_MANAGEMENT_IF inet static
  address $VM1_MANAGEMENT_IP
  network $MANAGMENT_NET
  netmask $MANAGEMENT_NET_MASK
  broadcast $MANAGEMENT_NET.254
  dns $VM_DNS " > $d/config-drives/$VM1_NAME-config/meta-data

#user-data vm1
echo "#!/bin/bash
ip link add $VXLAN_IF type vxlan id $VID remote $VM2_VXLAN_IP local $VM1_VXLAN_IP dstport 4789
ip link set $VXLAN_IF up
ip addr add $VM1_VXLAN_IP/24 dev $VXLAN_IF
curl -fsSl https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
  'deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable'
apt-get update
apt-get install docker-ce -y  " > $d/config-drives/$VM1_NAME-config/user-data



#meta-data vm2
echo "instance-id: vm2-toljika
hostname: $VM2_NAME
local-hostname: $VM2_NAME
network-interfaces: |
  auto $VM2_INTERNAL_IF
  iface $VM2_INTERNAL_IF inet static
  address $VM2_INTERNAL_IP
  network $INTERNAL_NET_IP
  netmask $INTERNAL_NET_MASK
  broadcast $INTERNAL_NET.254
  dns $VM_DNS

  auto $VM2_MANAGEMENT_IF
  ifcae $VM2_MANAGEMENT_IF inet static
  address $VM2_MANAGEMENT_IP
  network $MANAGMENT_NET
  netmask $MANAGEMENT_NET_MASK
  broadcast $MANAGEMENT_NET.254
  dns $VM_DNS " > $d/config-drives/$VM2_NAME-config/meta-data


#user-data vm2
echo "#!/bin/bash
ip link add $VXLAN_IF type vxlan id $VID remote $VM1_VXLAN_IP local $VM2_VXLAN_IP dstport 4789
ip link set $VXLAN_IF up
ip addr add $VM2_VXLAN_IP/24 dev $VXLAN_IF
curl -fsSl https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
  'deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable'
apt-get update
apt-get install docker-ce -y  " > $d/config-drives/$VM2_NAME-config/user-data


#сборка образа 
cp $VMs_qcow2 $VM1_HDD
cp $VMs_qcow2 $VM2_HDD

mkisofs -o "$VM1_CONFIG_ISO" -V cidata -r -J --quiet  $d/config-drives/$VM1_NAME-config
mkisofs -o "$VM2_CONFIG_ISO" -V cidata -r -J --quiet  $d/config-drives/$VM2_NAME-config


#запуск виртуалок

virsh define $d/$VM1_NAME.xml
virsh define $d/$VM2_NAME.xml

virsh start $VM1_NAME
virsh start $VM1_NAME
