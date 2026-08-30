# 一生一芯：NEMU 与 RISC-V CPU

本仓库存放基于“一生一芯”课程框架完成的个人代码实现，包含 RV32E 指令集模拟器 NEMU、RISC-V 处理器 NPC、Abstract Machine（AM）裸机运行时与 ysyxSoC 集成。

处理器架构、SoC 设计、基础设施与运行时环境设计、实验结果与性能分析参见[毕业论文仓库](https://github.com/Rom00000010/thesis)。

<p align="center">
  <img src="docs/overview.svg" alt="一生一芯项目整体架构" width="62%">
  <br>
  <sub>处理器系统设计与验证范围</sub>
</p>

## 代码关系

NEMU 与 NPC 分别提供同一 RISC-V 机器的软件模拟和 RTL 实现；两者使用 AM 定义的统一接口运行上层程序，NPC 以 NEMU 为参考模型进行 Difftest。

```text
                     ┌─ NEMU：软件指令集模拟器
程序 ── AM / Klib ──┤          ⇅ Difftest
                     └─ NPC：RTL 处理器 ── ysyxSoC
```

## 代码导览

| 路径 | 内容与个人实现范围 |
| --- | --- |
| `nemu/` | RV32E 指令译码与执行、设备模型、异常与上下文切换、调试器及指令/访存/函数调用追踪 |
| `abstract-machine/` | NEMU 与 NPC/ysyxSoC 的 AM 平台适配，以及 Klib 裸机基础库 |
| `npc/` | 四级流水线 RV32E 处理器、Verilator 仿真、Monitor/Trace、Difftest、ICache 与面积/时序优化 |
| `ysyxSoC/` | 个人 ysyxSoC 版本子模块，包含 SDRAM、PSRAM、SPI Flash 仿真与启动链路相关改动 |

## 验证范围

代码先后通过 RISC-V 指令测试，并运行 Microbench、设备测试与游戏程序；NPC 接入 ysyxSoC 后成功启动 RT-Thread。具体架构、综合结果和性能数据记录在毕业论文仓库中。

## 相关仓库

- [thesis](https://github.com/Rom00000010/thesis)：架构设计、实验结果、毕业论文与答辩材料
- [ysyxSoC](https://github.com/Rom00000010/ysyxSoC)：SoC 集成与存储设备仿真的个人实现版本

## 项目来源

本仓库基于[“一生一芯”课程](https://ysyx.oscc.cc/docs/)及 [ProjectN](https://github.com/NJU-ProjectN) 的课程框架完成；NEMU、Abstract Machine 和 ysyxSoC 等上游项目的版权与许可证归原作者所有。
