# RDMA 子系统架构设计（Architecture）

## 1. 文档目的

本文档在 `01_protocol_scope.md` 定义的协议范围约束下，给出 RDMA 子系统的**系统级架构设计**。

目标是明确：

* 子系统由哪些核心模块构成
* 各模块的职责边界
* TX / RX 数据通路的整体形态

本文档不涉及 RTL 实现细节、不涉及时序优化，也不讨论具体验证方法。

---

## 2. 架构设计前提

本架构严格遵循以下前提条件：

* 协议模型基于 RoCEv2（子集）
* 不支持乱序接收
* 不支持重传与拥塞控制
* 请求与 Completion 保序
* 功能优先于性能

任何违反上述前提的设计，不属于当前架构讨论范围。

---

## 3. 子系统总体视图

RDMA 子系统在系统中的逻辑位置如下：

Host
|
|  RDMA Requests / Doorbell
v
RDMA Subsystem
|
|  Ethernet / UDP / IP Packets
v
Network

子系统对 Host 提供 RDMA 语义接口，对 Network 提供以太网承载的报文接口。

---

## 4. 子系统模块划分

RDMA 子系统由以下逻辑模块构成：

* Host Interface
* QP Context Manager
* Request Scheduler
* Packet Engine
* Completion Engine
* Memory Interface（抽象层）

各模块通过明确接口连接，内部实现相互独立。

---

## 5. Host Interface

Host Interface 是 RDMA 子系统与 Host 侧交互的入口，主要职责包括：

* 接收 Host 提交的 RDMA 请求
* 解析请求类型与基本参数
* 将请求注入内部调度体系

Host Interface 不负责协议处理，仅负责语义级请求接入。

---

## 6. QP Context Manager

QP Context Manager 负责维护所有 Queue Pair 的上下文信息。

主要职责：

* QP 状态管理
* QP 配置参数维护
* 请求与 QP 的关联

该模块不参与具体数据通路处理，仅提供状态与配置支持。

---

## 7. Request Scheduler

Request Scheduler 负责将 Host 提交的 RDMA 请求转换为可执行的协议事务。

主要职责：

* 请求排队与仲裁
* 并发与 Outstanding 数量控制
* 请求生命周期管理

调度策略在当前阶段保持简单，可作为后续扩展点。

---

## 8. Packet Engine

Packet Engine 是 RDMA 子系统的核心协议处理模块，分为 TX 与 RX 两个方向。

### 8.1 TX Path

TX Path 的职责包括：

* 根据 RDMA 操作语义生成协议报文
* 封装 RoCEv2 / UDP / IP 头部（抽象）
* 向 Network 接口发送报文

TX Path 不涉及性能优化，仅保证协议语义正确。

### 8.2 RX Path

RX Path 的职责包括：

* 接收来自 Network 的报文
* 解析协议头与语义信息
* 将结果传递给 Completion Engine

RX Path 假设报文按序到达。

---

## 9. Completion Engine

Completion Engine 负责将协议处理结果转化为 Host 可感知的 Completion 事件。

主要职责：

* 生成 Completion 描述
* 保证 Completion 顺序
* 将结果返回 Host Interface

Completion 语义严格服从 Request 顺序。

---

## 10. Memory Interface（抽象层）

Memory Interface 用于抽象 RDMA 操作涉及的数据存取行为。

当前阶段：

* 作为逻辑占位模块存在
* 不实现真实内存访问
* 用于隔离协议逻辑与数据存取细节

后续阶段可逐步扩展该接口能力。

---

## 11. TX / RX 数据通路总结

整体数据通路如下：

Host Request
-> Host Interface
-> Request Scheduler
-> Packet Engine (TX)
-> Network
-> Packet Engine (RX)
-> Completion Engine
-> Host

该通路构成最小可运行 RDMA 子系统闭环。

---

## 12. 可扩展性说明

本架构在以下位置预留扩展空间：

* QP 数量与并发能力
* 请求调度策略
* Packet Engine 内部处理复杂度
* Completion 管理机制

所有扩展必须以不破坏当前模块边界为前提。

---

## 13. 与后续文档的关系

* 本文档为 `03_interface_spec.md` 提供模块级拆分依据
* 接口定义必须严格遵循本文档模块边界
* 验证计划应覆盖本文档描述的完整数据通路
