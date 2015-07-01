#!/bin/bash

## Dependencies
# sudo modprobe kvm
# sudo service virtualbox stop
# sudo service qemu-kvm start
# sudo apt-get install kvm cloud-utils genisoimage

function print_help(){
    echo -e \
"Usage of $0:\n" \
"   $0 [options]\n" \
"Options:\n" \
"   -r | --repository REPO - GIT repository of kZorp \n" \
"   -b | --branch BRANCH - branch name of the repository where kZorp is compiled from \n" \
"   -a | --arch ARCHITECTURE - Architecture name of the package to be installed\n" \
"   -v | --version VERSION - Ubuntu version to run the test with\n" \
"   -p | --path PATH - Path of the tests directory\n"
"   -h | --help - Display this information \n"
}

Repository="https://github.com/balabit/kzorp.git"
Branch="master"

Root="/tmp/kzorp_test_run"

TestSeedConf="run_test.conf"

Architecture="amd64"

OSVersion="14.04"

while (( $# )); do
  case $1 in
    "-r" | "--Repository") Repository="$2"; shift 2;;
    "-b" | "--branch") Branch="$2"; shift 2;;
    "-a" | "--arch") Architecture="$2"; shift 2;;
    "-v" | "--version") OSVersion="$2"; shift 2;;
    "-p" | "--path") Root="$2"; shift 2;;
    "-h" | "--help") print_help; exit 0;;
    *) echo "Invalid option $1" >&2; print_help; exit 1;;
  esac
done

case ${Architecture} in
  "amd64") Qemu="qemu-system-x86_64 --enable-kvm";;
  "i386") Qemu="qemu-system-i386 --enable-kvm";;
  "arm64") Qemu="qemu-system-arm -machine virt";;
  *) echo "Error: ${Architecture} is not a supported architecture. Only amd64, i386 and arm64 are supported."; exit 1;;
esac

TestRoot="${Root}/tests"
OSImageDir="${Root}/disk_images"
OSImageName="disk.img.dist_${OSVersion}_${Architecture}"
OSImagePath="${OSImageDir}/${OSImageName}"
OSImagePathOrig="${OSImageDir}/${OSImageName}.orig"
OSImagePathQemu="${OSImageDir}/${OSImageName}.qemu"
OSImagePathSeed="${OSImageDir}/${OSImageName}.seed"

ImageURL="http://cloud-images.ubuntu.com/server/releases/${OSVersion}/release"
ImageURL="${ImageURL}/ubuntu-${OSVersion}-server-cloudimg-${Architecture}-disk1.img"

if [ ! -d ${OSImageDir} ]; then
  mkdir -p ${OSImageDir}
fi

## download the image (only once)
if [ ! -f ${OSImagePath} ]; then
  echo "Image not found under ${OSImagePath}"
  wget $ImageURL -O ${OSImagePath}
fi

## Create a file with some user-data in it
mkdir -p $TestRoot
touch $TestRoot/result.xml

cat > $TestSeedConf <<EOF
#cloud-config
password: zorp
chpasswd: { expire: False }
ssh_pwauth: True
packages:
 - git
 - build-essential
 - linux-headers-generic
 - autoconf
 - libtool
 - python-prctl
 - python-nose
runcmd:
 - set -x
 - mkdir -p $TestRoot
 - sudo mount -t 9p -o trans=virtio,version=9p2000.L hostshare $TestRoot
 - cd
 - git clone $Repository
 - cd kzorp
 - git checkout $Branch
 - autoreconf -i
 - ./configure
 - sudo make install-driver
 - TEST_PYTHONPATH=\$PWD/pylib:\$PWD/driver/tests/base
 - TEST_FILES=\`find driver/tests/ -name KZorpTestCase\*.py -printf "%p "\`
 - sudo bash -c "PYTHONPATH=\$PYTHONPATH:\$TEST_PYTHONPATH nosetests --with-xunit \$TEST_FILES"
 - cp nosetests.xml ${TestRoot}/result.xml
 - sudo poweroff
EOF


if [ ! -f ${OSImagePathOrig} ]; then
  ## Convert the compressed qcow file downloaded to a uncompressed qcow2
  qemu-img convert -O qcow2 ${OSImagePath} ${OSImagePathOrig}
fi

## create the disk with NoCloud data on it.
cloud-localds ${OSImagePathSeed} $TestSeedConf

## Create a delta disk to keep our .orig file pristine
qemu-img create -f qcow2 -b ${OSImagePathOrig} ${OSImagePathQemu}

## Boot a kvm
#In a terminal you can login to the machine through the curses interface
#qemu-system-x86_64 --enable-kvm -curses -net nic -net user -hda ${OSImagePathQemu} -hdb ${OSImagePathSeed} -m 2048 -fsdev local,security_model=passthrough,id=fsdev0,path=$TestRoot -device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=hostshare
#Jenkins runs this without terminal
${Qemu} -nographic -net nic -net user -hda ${OSImagePathQemu} -hdb ${OSImagePathSeed} -m 2048 -fsdev local,security_model=passthrough,id=fsdev0,path=$TestRoot -device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=hostshare

cp ${TestRoot}/result.xml result.xml
