#!/bin/bash

d=`dirname $0`
cd $d

#доп параметры
. "$d/config"

MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`
mkdir networks
mkdir config-drives


#обновления и доп пакеты
apt update -y

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
      <mac address='$MAC'>
      <source network='$EXTERNAL_NET_NAME'/>
      <model type='virtio'/>
    </interface>
    <interface type='network'>
      <mac address='$MAC'>
      <source network='$INTERNAL_NET_NAME'/>
      <model type='virtio'/>
    </interface>
    <interface type='network'>
      <mac address='$MAC'>
      <source network='$MANAGEMENT_NET_NAME'/>
      <model type='virtio'/>
    </interface>
  </devices>
</domain>" > $VM1_NAME




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
      <mac address='$MAC'>
      <source network='$INTERNAL_NET_NAME'/>
      <model type='virtio'/>
    </interface>
    <interface type='network'>
      <mac address='$MAC'>
      <source network='$MANAGEMENT_NET_NAME'/>
      <model type='virtio'/>
    </interface>
  </devices>
</domain>" > $VM2_NAME

