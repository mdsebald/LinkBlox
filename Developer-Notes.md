#### LinkBlox Developer Notes

Might be some useful information here:

https://coelhorjc.wordpress.com/2015/02/25/how-to-build-and-package-erlang-otp-applications-using-rebar/

Attempting to integrate with nerves project using linux to build.

Under linux, follow the instructions for nerves-system-br to build with the appropriate defconfig (i.e. nerves_rpi_defconfig) for your platform 

Set environment variables so your project can connect with the nerves project

$ source ./nerves-env.sh.

after cloning project, 

$ chmod +x relhelper.sh   # make it executable

Erlang ALE Makefile calls erlang.mk for make rules

ERTS_INCLUDE_DIR="$(ERTS_DIR)/include"

ERL_INTERFACE_LIB_DIR="$(ERL_EI_LIBDIR)"

ERL_INTERFACE_INCLUDE_DIR="$(ERL_EI_INCLUDE_DIR)"  

Made this a pull request to nerves project, to update "scripts/nerves-env-helper.sh" and nerves.mk

Pull request accepted 09-Jan-2016

Need to switch Makefile to use fwup app to burn SD memory card instead of using fwtool

fwup, not in sudo env PATH,  i.e. ./nerves-system-br/buildroot/output/target/usr/bin/fwup

Copy source from Vagrant synced folder (Local GitHub Repo) to nerves LinkBlocks build directory (under /home/vagrant)

$ rsync -avC /vagrant/github/LinkBlocks .  

Error running rebar:  rebar.config references ./relhelper.sh  sript.  Error: could not find ./relhelper.sh  

Cause: relhelper.sh had DOS line endings.  Needed to switch to unix line endings used this:

 http://stackoverflow.com/questions/2920416/configure-bin-shm-bad-interpreter

