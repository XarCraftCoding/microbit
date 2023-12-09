# Microbit

This repository contains the source code of `Microbit` operating system.
It is called `Microbit` because it is mostly coded in `Micro` code editor in `Linux` and it is a tiny operating system 🔥.

## Building

> You have to have `Git` installed on your computer.

First, you have to install `qemu`, `nasm`, `make` and `micro`.
To install those you have to run these commands:

```bash
sudo apt install make nasm qemu
sudo snap install micro --classic
```

Then, run these commands:

```bash
git clone https://github.com/XarCraftCoding/Microbit
cd Microbit
make
qemu-system-i386 -fda build/main_floppy.img
```

or, you can just run `build.sh`.
