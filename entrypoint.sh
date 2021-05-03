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
  make gcc gcc-multilib g++-multilib libsdl2-dev udev

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
yes | ./zephyr-sdk-0.12.4-x86_64-linux-setup.run -- -d ~/zephyr-sdk-0.12.4

cp ~/zephyr-sdk-0.12.4/sysroots/x86_64-pokysdk-linux/usr/share/openocd/contrib/60-openocd.rules /etc/udev/rules.d
udevadm control --reload

echo "Create the codeql database" 
mkdir /src/cpp-db
# the actual build
cd ~/zephyrproject/zephyr
# build the sample for the board
# west build -p auto -b "NXP MIMXRT1064-EVK" samples/basic/blinky
for module in basic bluetooth; do
	echo "checking module $module"
	ls samples/$module/ | grep -v '\.' | while read app; do
	        echo "checking module $module app $app"
		codeql database create /src/cpp-db/$module-$app --language=cpp --command="west build -p auto -b mimxrt1064_evk samples/$module/$app"
		echo "Run the queries to find results in $module-$app"
		codeql database analyze -j0 /src/cpp-db/$module-$app /root/codeql-repo/cpp/ql/src/Likely\ Bugs/ \
			/root/codeql-repo/cpp/ql/src/Best\ Practices/ \
			/root/codeql-repo/cpp/ql/src/Critical/ \
			/root/codeql-repo/cpp/ql/src/experimental/ \
			--format=csv --output /src/$module-$app-cpp-results.csv
		CWE=$(ls -d /root/codeql-repo/cpp/ql/src/Security/CWE/* | grep -v CWE-020)
		codeql database analyze -j0 /src/cpp-db/$module-$app $CWE --format=csv --output /src/$module-$app-cpp-security-results.csv
	done
done
