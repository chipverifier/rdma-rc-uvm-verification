debImport "-sv" "../verification/tb_rdma_rc_qp.sv" "../rtl/qp/rdma_rc_qp.v" "-l" \
          "verdi.log"
nsMsgSwitchTab -tab general
srcHBSelect "std.randomize" -win $_nTrace1 -lib "work"
srcSetScope -win $_nTrace1 "std.randomize" -delim "." -lib "work"
srcHBSelect "std.randomize" -win $_nTrace1 -lib "work"
nsMsgSwitchTab -tab cmpl
nsMsgSwitchTab -tab general
nsMsgSwitchTab -tab cmpl
nsMsgSwitchTab -tab trace
nsMsgSwitchTab -tab search
nsMsgSwitchTab -tab cmpl
nsMsgSelect -range {0-0}
nsMsgSelect -range {0 0-0}
debExit
