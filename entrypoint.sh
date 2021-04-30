#!/bin/bash
set -x

cd /src/
# run codeql 
if [ -s cpp-db ];then
	rm -r cpp-db
fi
echo "Install the dependencies for compiling the repository"
# https://docs.zephyrproject.org/latest/getting_started/index.html
apt-get update -yqq
apt-get install -yqq --no-install-recommends git cmake ninja-build gperf \
  ccache dfu-util device-tree-compiler wget \
  python3-dev python3-pip python3-setuptools python3-tk python3-wheel xz-utils file \
  make gcc gcc-multilib g++-multilib libsdl2-dev

echo "verify if cmake is version 3.13.1 or higher"
cmake --version

pip3 install west
echo 'export PATH=~/.local/bin:"$PATH"' >> ~/.bashrc
source ~/.bashrc

west init ~/zephyrproject
cd ~/zephyrproject
west update
west zephyr-export

pip3 install -r ~/zephyrproject/zephyr/scripts/requirements.txt
cd ~ 
rm zephyr-sdk-*.run*
wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.12.4/zephyr-sdk-0.12.4-x86_64-linux-setup.run
chmod +x zephyr-sdk-0.12.4-x86_64-linux-setup.run
./zephyr-sdk-0.12.4-x86_64-linux-setup.run -- -d ~/zephyr-sdk-0.12.4

cp ~/zephyr-sdk-0.12.4/sysroots/x86_64-pokysdk-linux/usr/share/openocd/contrib/60-openocd.rules /etc/udev/rules.d
udevadm control --reload

echo "Create the codeql database" 
# the actual build
cd ~/zephyrproject/zephyr
# build the sample for the board
# west build -p auto -b "NXP MIMXRT1064-EVK" samples/basic/blinky
codeql database create /src/cpp-db/basic-blinky --language=cpp --command="west build -p auto -b mimxrt1064_evk samples/basic/blinky"
echo "Run the queries to find results"
codeql database analyze -j0 /src/cpp-db/basic-blinky /root/codeql-repo/cpp/ql/src/Likely\ Bugs/ \
	/root/codeql-repo/cpp/ql/src/Best\ Practices/ \
	/root/codeql-repo/cpp/ql/src/Critical/ \
	/root/codeql-repo/cpp/ql/src/experimental/ \
	--format=csv --output /src/basic-blinky-cpp-results.csv

CWE=$(ls -d /root/codeql-repo/cpp/ql/src/Security/CWE/* | grep -v CWE-020)
codeql database analyze -j0 /src/cpp-db/basic-blinky $CWE --format=csv --output /src/basic-blinky-cpp-security-results.csv

codeql database create /src/cpp-db/basic-rgb_led --language=cpp --command="west build -p auto -b mimxrt1064_evk samples/basic/rgb_led"
echo "Run the queries to find results"
codeql database analyze -j0 /src/cpp-db/basic-rgb_led /root/codeql-repo/cpp/ql/src/Likely\ Bugs/ \
	/root/codeql-repo/cpp/ql/src/Best\ Practices/ \
	/root/codeql-repo/cpp/ql/src/Critical/ \
	/root/codeql-repo/cpp/ql/src/experimental/ \
	--format=csv --output /src/basic-rgb_led-cpp-results.csv

CWE=$(ls -d /root/codeql-repo/cpp/ql/src/Security/CWE/* | grep -v CWE-020)
codeql database analyze -j0 /src/cpp-db/basic-rgb_led $CWE --format=csv --output /src/basic-rgb_led-cpp-security-results.csv

