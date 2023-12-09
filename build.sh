echo -e \nInstalling the Libraries...\n
sudo apt install make nasm qemu
sudo snap install micro --classic
echo -e \nTask Success!\n

echo -e \nInstalling the Source Code...\n
git clone https://github.com/XarCraftCoding/Microbit
cd Microbit
echo -e \nTask Success!\n

echo Running...
make
qemu-system-i386 -fda build/main_floppy.img
echo \nTask Success!\n