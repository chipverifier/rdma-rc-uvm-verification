#!/bin/bash
set -e
mkdir -p log wave cov
vcs \
-sverilog \
-full64 \
-timescale=1ns/1ps \
+lint=TFIPC-L \
-CFLAGS "-std=c++11 -DSYNOPSYS" \
+incdir+$UVM_HOME/src \
$UVM_HOME/src/uvm_pkg.sv \
$UVM_HOME/src/dpi/uvm_dpi.cc \
-debug_access+all \
+fsdb \
-f ../cfg/filelist_basic.f \
-l log/compile.log \
-P $VERDI_HOME/share/PLI/VCS/LINUX64/novas.tab \
$VERDI_HOME/share/PLI/VCS/LINUX64/pli.a
./simv \
+cover=stmt+branch+cond \
+UVM_NO_RELNOTES \
-l log/sim.log
grep -E "Coverage|stmt|branch|cond" log/sim.log