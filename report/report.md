# Lab1 实验报告

## 一、实验目的及内容

## 二、实验环境搭建及验证
本实验基于WSL2 Ubuntu22.04 LTS开展，从oslab拉取lab1的代码后，我们寄存在目录os_homework/code下。

随后，我们设置RISC-V环境变量：
```bash

mkdir -p ~/riscv
vim ~/.bashrc

#跳转至最后一行
export RISCV=$HOME/riscv
export PATH=$RISCV/bin:$PATH

#保存退出，随后应用
source ~/.bashrc
echo $RISCV

#输出结果正确，环境变量生效
/home/sparkwang/riscv
```
获取riscv64-unknown-elf-toolchain后，解压，执行：
```bash
riscv64-unknown-elf-gcc -v

#输出结果正确，安装完成
gcc version 10.2.0 (SiFive GCC-Metal 10.2.0-2020.12.8)
```
随后从Qemu官方网站获取qemu-4.1.1，解压后执行：
```bash
cd qemu-4.1.1
./configure --target-list=riscv32-softmmu,riscv64-softmmu --extra-cflags="-fcommon"
make -j$(nproc)

#验证版本
qemu-system-riscv64 --version

#输出结果正确，安装完成
QEMU emulator version 4.1.1
Copyright (c) 2003-2019 Fabrice Bellard and the QEMU Project developers
```
至此，实验基本环境搭建完成。
## 三、工程编译与运行
将目录切换到/os_homework/code下，执行：
```bash
make qemu
```
运行结果如下：
![QEMU运行结果](images/01_qemu_run.png)

随后通过Ctrl+a，松开后执行x，退出Qemu。

接下来在终端1执行：
```bash
make gdb
```
然后新建终端2执行：
```bash
#在相同工程目录下
make gdb
```
这一阶段用于实现GDB的正常使用和远程连接，输出结果如图所示：
![GDB运行结果](images/02_gdb_run.png)

至此，基本的工程编译运行已经完成，接下来开展基于GDB的调试验证。
## 四、总结与反思
