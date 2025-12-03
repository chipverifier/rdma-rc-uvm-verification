#!/bin/bash
# compile.sh - VCS编译脚本
# 依赖：VCS、Verdi已安装并配置环境变量

# 清除旧文件
rm -rf simv* csrc* *.log *.fsdb *.vpd

# VCS编译命令
vcs \
    -sverilog \
    -full64 \
    -debug_access+all \
    -fsdb \
    -l compile.log \
    ../verification/tb_rdma_rc_buf.sv \
    ../rtl/buf/rdma_rc_buf.v \
    -P ${VERDI_HOME}/share/PLI/VCS/LINUX64/novas.tab ${VERDI_HOME}/share/PLI/VCS/LINUX64/pli.a

# 编译成功判断
if [ -f "simv" ]; then
    echo "编译成功！生成simv可执行文件"
else
    echo "编译失败！查看compile.log"
    exit 1
fi