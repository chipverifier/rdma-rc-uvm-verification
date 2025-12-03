#!/bin/bash
# run.sh - 仿真运行脚本

# 执行仿真
./simv -l run.log

# 仿真成功判断
if [ -f "tb_rdma_rc_buf.fsdb" ]; then
    echo "仿真成功！生成tb_rdma_rc_buf.fsdb波形文件"
else
    echo "仿真失败！查看run.log"
    exit 1
fi