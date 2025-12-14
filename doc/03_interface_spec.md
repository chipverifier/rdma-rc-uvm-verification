本文件定义 RDMA 子系统中各核心模块之间的接口规范，站在系统与架构视角描述“模块如何协作”，而非信号级或实现级细节。

本接口规范的目标是：

1. 明确模块责任边界，防止职责蔓延
2. 固化模块间交互语义，支撑长期演进
3. 为后续 RTL 实现与验证提供稳定契约

当前版本仅覆盖 RoCEv2 协议子集，其他协议或能力不在本文档范围内。

---

一、接口设计总原则

1. 决策与执行分离
   所有策略性决策必须集中在 Scheduler 模块完成，其它模块只负责执行既定语义，不进行二次判断。

2. 显式语义接口
   模块之间传递的是“语义对象”而非隐式状态或信号组合，禁止通过时序或 side effect 传递含义。

3. 单向依赖，禁止环形控制
   RX 路径不直接驱动 TX 行为，所有闭环必须通过 Scheduler 完成。

4. 接口稳定优先于实现灵活性
   一旦接口语义确定，内部实现可重构，但接口行为必须保持兼容。

---

二、模块与接口关系总览

系统包含以下核心模块：

* Host / Driver
* Scheduler
* TX Packet Engine（TPE）
* RX Packet Parser
* Reliability / State Tracker
* Completion Engine

接口关系按数据与控制流划分如下：

1. Host / Driver → Scheduler
2. Scheduler → TX Packet Engine
3. TX Packet Engine → TX MAC / NIC
4. RX MAC / NIC → RX Packet Parser
5. RX Packet Parser → Reliability / State Tracker
6. Reliability / State Tracker → Scheduler
7. Scheduler → Completion Engine → Host

本文档仅关注 1、2、6 三类“语义接口”，其余接口视为数据通路，不展开描述。

---

三、Host / Driver → Scheduler 接口

接口目标：
向系统提交一次 RDMA 操作请求。

语义定义：
Host 提交的请求描述的是“我希望完成什么 RDMA 操作”，而不是“如何发送数据包”。

接口包含的核心语义：

* QP 标识
* RDMA 操作类型（SEND / WRITE / READ 等）
* 数据缓冲区与长度
* 是否需要 Completion 通知

接口不包含的内容：

* PSN 管理
* 分片规则
* 协议字段

这些能力由 Scheduler 统一负责。

---

四、Scheduler → TX Packet Engine 接口

接口目标：
将一次 RDMA 操作转化为可执行的协议封包请求。

语义对象：
PacketRequest（逻辑概念）

PacketRequest 表示“一次已经做完所有决策的协议执行请求”。

接口语义包括：

* QP 标识
* RDMA Opcode
* 起始 PSN
* 总数据长度
* MTU 约束信息
* Payload 来源描述

责任边界说明：

* Scheduler 负责：

  * 是否发送
  * 发送顺序
  * 是否重传

* TX Packet Engine 负责：

  * 协议头生成
  * 数据分片
  * Packet 顺序输出

TX Packet Engine 不维护任何全局协议状态，也不具备策略决策能力。

接口交互模型：

* Scheduler 提交 PacketRequest
* TX Packet Engine 返回执行状态（可接受 / 忙 / 错误）

---

五、Reliability / State Tracker → Scheduler 接口

接口目标：
向 Scheduler 汇报 RX 路径产生的协议事件。

接口语义：
该接口传递的是“事实与事件”，而不是“动作指令”。

事件类型示例：

* DATA_RECEIVED
* ACK_RECEIVED
* NACK_RECEIVED
* PSN_ERROR

每个事件至少包含：

* QP 标识
* PSN 信息
* 事件类型
* 附加状态描述

责任边界说明：

* RX 侧模块不直接触发 TX 行为
* Scheduler 根据事件自行决定：

  * 是否发送 ACK
  * 是否触发重传
  * 是否推进窗口

---

六、Scheduler → Completion Engine 接口

接口目标：
在 RDMA 操作完成时生成 Completion 语义。

接口语义：
Scheduler 明确判定一次 RDMA 操作完成后，向 Completion Engine 发送完成事件。

Completion Engine 负责：

* 生成 CQE
* 通知 Host

Completion Engine 不参与协议处理，不影响数据路径。

---

七、当前版本的刻意限制

为保证系统清晰与可扩展性，当前接口规范明确不包含以下内容：

* 拥塞控制相关接口
* 多路径与负载均衡
* 原子操作语义
* 错误恢复策略细节

这些能力将在后续 roadmap 中定义扩展方式。

---

八、接口规范的演进原则

* 新能力优先通过扩展语义对象实现
* 禁止破坏既有接口含义
* 接口版本升级必须保持向后兼容

本文件作为系统级接口契约，应长期稳定存在，并随系统演进逐步扩展。
