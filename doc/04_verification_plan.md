本文件从系统与架构视角定义 RDMA 子系统的验证策略，目标是证明在既定接口契约与协议范围内，系统行为是正确、可预测且可收敛的。

本文档不描述具体 testcase、不涉及 UVM 架构或信号级细节，仅定义“需要被证明的系统级行为”。

---

一、验证目标（Verification Goals）

系统级验证的核心目标是：
在 RoCEv2 子集协议范围内，RDMA 子系统在正常与异常输入条件下，均能表现出符合架构定义的行为。

具体目标包括：

1. Host 发起的 RDMA 请求能够被完整、正确地执行
2. 协议行为在已支持范围内保持一致性
3. RX → Scheduler → TX 闭环行为具备确定因果关系
4. 异常输入不会破坏系统稳定性
5. 模块责任边界不被破坏

---

二、验证范围与刻意排除

### 验证范围

* RoCEv2 RC 模式子集
* 基本 RDMA 操作（SEND / WRITE / READ）
* 单端口、单路径场景
* 正常与有限异常协议输入

### 刻意排除

* 拥塞控制（ECN / CNP）
* 多路径与负载均衡
* 原子操作
* 性能、吞吐与时延指标

这些能力将在后续版本中通过接口扩展引入。

---

三、系统级可观测点（Observability）

系统验证不依赖内部实现细节，而基于以下可观测语义点：

1. Host 接口层事件

   * RDMA 请求提交
   * Completion 产生

2. RX 语义事件

   * DATA_RECEIVED
   * ACK_RECEIVED
   * NACK_RECEIVED
   * PSN_ERROR

3. Scheduler 决策输出

   * PacketRequest 的生成
   * Completion 触发决策

4. TX 行为输出

   * PacketRequest 被执行
   * 发包类型与 PSN 范围

这些观测点构成系统级因果验证的基础。

---

四、RX → Scheduler → TX 闭环验证策略

### 4.1 闭环定义

RX → Scheduler → TX 构成 RDMA 可靠传输的核心控制闭环。
验证的重点不在于单个 packet，而在于：

RX 输入事件 → Scheduler 决策 → TX 行为

三者之间是否存在确定且合法的映射关系。

---

### 4.2 RX 事件抽象

RX 收包在系统级被抽象为有限事件集合，包括但不限于：

* DATA_RECEIVED(qp, psn)
* ACK_RECEIVED(qp, psn)
* NACK_RECEIVED(qp, psn)
* PSN_ERROR(qp)

RX 模块仅产生事件，不直接触发 TX 行为。

---

### 4.3 Scheduler 合法决策空间

Scheduler 的对外可观测决策被限制在封闭集合内：

* SEND_ACK
* RETRANSMIT(psn_range)
* ADVANCE_WINDOW
* NO_ACTION

验证需确保 Scheduler 不产生协议外或未定义的行为。

---

### 4.4 TX 行为约束

TX 行为需满足以下系统约束：

* 所有 TX 行为均可追溯到 Scheduler 决策
* 发包不跨 QP
* PSN 不越界、不倒退
* 分片与顺序符合协议定义

---

五、系统级不变量（System Invariants）

以下不变量在所有验证场景中必须成立：

1. 决策唯一性

   * 任一 TX 行为只能由 Scheduler 决策触发

2. 行为封闭性

   * 系统不会生成未在接口规范中定义的协议行为

3. 顺序一致性

   * 同一 QP 上 TX 行为保持顺序语义

4. 闭环可收敛性

   * RX / TX 交互不会导致无限循环或死锁

---

六、异常与边界场景验证原则

系统需在以下场景下保持稳定：

* 重复 ACK
* 非期望 PSN 的 DATA
* 窗口外 ACK / NACK
* Payload 长度为 0 或边界值

验证目标是：

* 系统状态不崩溃
* QP 不进入不可恢复状态

不要求在当前版本实现完整错误恢复策略。

---

七、模块责任一致性验证

验证需确认：

* Scheduler 负责所有协议决策
* TX Packet Engine 仅执行 PacketRequest
* RX 模块不直接影响 TX 行为
* Completion Engine 只处理完成语义

任何责任越界均视为系统级错误。

---

八、验证演进策略

* 新功能引入时，优先扩展系统不变量与事件类型
* 验证计划应随接口规范同步演进
* 不破坏既有验证结论

本文件作为系统级验证依据，应长期维护，并作为架构一致性的参考文档。
