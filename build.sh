echo Installing the Libraries...
sudo apt install make nasm qemu bochs bochs-sdl bochsbios vgabios
sudo snap install micro --classic
echo Task Success!

echo Installing the Source Code...
git clone https://github.com/XarCraftCoding/Microbit
echo Task Success!

echo Running...
cd Microbit
make
./run.sh
echo Task Success!