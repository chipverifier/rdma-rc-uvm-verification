#!/bin/bash
set -e

vcs \
-sverilog \
-full64 \
-timescale=1ns/1ps \
+lint=TFIPC-L \
-CFLAGS "-std=c++11 -DSYNOPSYS" \
+incdir+$UVM_HOME/src \
$UVM_HOME/src/uvm_pkg.sv \
$UVM_HOME/src/dpi/uvm_dpi.cc \
-debug_region+cell \
-debug_access+all \
-fsdb \
+fsdbfile=wave/rdma.fsdb \
-f ../cfg/filelist_basic.f \
-l log/compile.log \
-P $VERDI_HOME/share/PLI/VCS/LINUX64/novas.tab \
$VERDI_HOME/share/PLI/VCS/LINUX64/pli.a

./simv
