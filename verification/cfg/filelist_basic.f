// RTL
../../rtl/rx/rdma_rx.v
../../rtl/qp/qp_context.v
../../rtl/sched/rdma_sched.v
../../rtl/tx/rdma_tx.v
../../rtl/completion/rdma_completion.v
../../rtl/top/rdma_top.v

//common
../common/common_pkg.sv

//trans
../../verification/trans/rdma_txn.sv
../../verification/tb/rdma_if.sv

//env
../../verification/env/rdma_seq_item.sv
../../verification/env/rdma_sequencer.sv
../../verification/env/rdma_sequence.sv
../../verification/env/rdma_monitor.sv
../../verification/env/rdma_driver.sv
../../verification/env/rdma_agent.sv
//host
../../verification/env/rdma_host_seq_item.sv
../../verification/env/rdma_host_sequencer.sv
../../verification/env/rdma_host_sequence.sv
//../../verification/env/rdma_host_monitor.sv
../../verification/env/rdma_host_driver.sv
../../verification/env/rdma_host_agent.sv
//complete
../../verification/env/rdma_complete_seq_item.sv
../../verification/env/rdma_complete_monitor.sv
../../verification/env/rdma_complete_agent.sv

../../verification/env/rdma_rm.sv
../../verification/env/rdma_rm_dpi.cpp
../../verification/env/rdma_scb.sv

../../verification/env/rdma_env.sv
//tc
../../verification/tc/rdma_test.sv
//tb
../../verification/tb/tb_rdma_top.sv
