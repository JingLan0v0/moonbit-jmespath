# MoonJMES

简体中文 | [English](README.md)

[![CI](https://github.com/JingLan0v0/moonbit-jmespath/actions/workflows/ci.yml/badge.svg)](https://github.com/JingLan0v0/moonbit-jmespath/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

MoonJMES 是用 MoonBit 原生实现的 JMESPath JSON 查询引擎和命令行工具。它可以从 API 响应、云资源清单、审计记录和配置文件中筛选、投影、排序并重组 JSON，无需嵌入 JavaScript，也无需把数据发送到外部服务。

项目在固定版本 `53abcc37901891cf4308fcd910eab287416c4609` 上通过 **892/892 项 JMESPath 官方合规测试**。测试过程可通过 `node scripts/conformance.mjs` 独立复现，详细记录见 [docs/conformance.md](docs/conformance.md)。

## 为什么做这个项目

JSON 是接口与自动化工具最常见的数据格式之一，但程序通常需要反复编写遍历、判空、过滤和排序代码。JMESPath 提供了正式语法和跨语言一致的查询语义，适合把查询表达式与业务程序分离。

MoonJMES 将完整的词法分析、语法解析、抽象语法树和执行器放在 MoonBit 库中，并同时提供可以直接处理文件或标准输入的 CLI。项目启动时对 Mooncakes 的检索没有发现同名或同规范的 MoonBit JMESPath 实现；这一结论只描述当时的检索结果，不排除后续出现其他实现。

## 功能

- 标识符、带引号标识符、当前节点、JSON 字面量和原始字符串
- 对象与数组通配、扁平化、投影、过滤、索引和切片
- 管道、比较、布尔表达式、多选列表和多选对象
- 标准标量、集合、转换和表达式引用函数
- `map`、`sort_by`、`min_by`、`max_by` 等高阶查询
- 可重复使用的预编译表达式，以及一次性 JSON 和文本 API
- 带逐项结构化错误的批量查询接口
- 表达式长度、AST 深度、执行步数和结果数量限制
- 支持文件和标准输入、紧凑输出及批量模式的 CLI

## 安装

从 Mooncakes 安装：

当前仅支持 **JS 后端**。CI 固定使用 MoonBit `0.10.14+7d59c7ec9` 和 Node.js
`24.14.0`，详见 `toolchain.json`。`moon add` 安装的是库依赖，不会安装全局 CLI。

```powershell
moon add JingLan0v0/jmespath
```

Mooncakes 页面：<https://mooncakes.io/docs/JingLan0v0/jmespath>

在 `moon.pkg` 中导入：

```moonbit
import {
  "JingLan0v0/jmespath" @jmespath,
  "moonbitlang/core/json",
}
```

调用公共 API：

```moonbit
let input = @json.parse("{\"people\":[{\"name\":\"Ada\",\"age\":36}]}")
let query = @jmespath.compile("people[?age >= `18`].name")
let result = query.search(input)
```

主要入口包括 `compile`、`Compiled::search`、`search`、`search_json` 和 `search_batch`。库调用方可用 `stringify_bounded(result, pretty=true)` 获得与 CLI 相同的输出保护。

上方是函数体内的代码片段，调用方需要处理或传递错误。仓库提供包含导入、可执行入口、
自定义限制、重复查询及错误处理的完整示例：`moon run examples/library --target js`。
详细约定见 [API 与错误说明](docs/usage.md)。

## PowerShell 使用方式

仓库提供 `scripts/moon.ps1`，会优先使用本地固定版本的 MoonBit 工具链，也可以回退到系统中的 `moon`：

首次使用先克隆并进入仓库：

```powershell
git clone https://github.com/JingLan0v0/moonbit-jmespath.git
cd moonbit-jmespath
```

```powershell
.\scripts\moon.ps1 check --target js
.\scripts\moon.ps1 test --target js
.\scripts\moon.ps1 run cmd/main --target js -- "instances[?state == 'running'].id" examples/cloud-inventory.json
```

从标准输入查询：

```powershell
'{"items":[{"name":"A","price":9},{"name":"B","price":12}]}' |
  .\scripts\moon.ps1 run cmd/main --target js -- 'items[?price >= `10`].name' -
```

输出为：

```json
[
  "B"
]
```

## 批量模式

批量输入是由独立请求组成的 JSON 数组：

```json
[
  {"expression":"name","data":{"name":"Ada"}},
  {"expression":"length()","data":null}
]
```

```powershell
.\scripts\moon.ps1 run cmd/main --target js -- --batch examples/batch.json
```

每个返回项都包含 `ok: true` 和 `result`，或者 `ok: false` 和结构化 `error`。错误表达式或格式错误的请求项不会丢弃同批次中的其他结果；顶层 JSON 本身无效时命令以退出码 2 结束。

**批量模式中，即使部分请求失败，命令仍以 0 退出**，调用方须逐项检查 `ok`。
仓库示例文件还包含第三个成功的缺失值回退查询，用于演示错误后的继续执行。

## 三个可运行场景

[`examples`](examples/README.md) 目录包含三组带固定预期输出的场景：

1. 从云资源清单中筛选生产环境且正在运行的实例。
2. 从部署审计记录中提取被拒绝的服务及机器可读原因码。
3. 按月度成本排序服务，为报表或仪表盘生成稳定结果。

Windows 下可运行 `./examples/run.ps1`，脚本会将实际结果与仓库中的预期 JSON 逐项比较。

## 验证

```powershell
.\scripts\moon.ps1 fmt --check
.\scripts\moon.ps1 check --target js
.\scripts\moon.ps1 test --target js
.\scripts\moon.ps1 info --target js
node scripts/verify.mjs
node scripts/conformance.mjs
node scripts/conformance.mjs --release
```

GitHub Actions 使用固定编译器版本，在 Windows 和 Ubuntu 上执行构建、测试、示例、接口一致性检查和全部官方合规用例。

## 九月验收问题的修复（0.1.2）

原发布版遇到由 **4000 个 `!` 加一个 `@`** 构成的 4001 字符表达式时，虽然没有超过默认长度上限，解析器却在完成深度检查前递归过深，导致进程栈溢出。三项批处理中间一项出错时，整批没有输出并以状态码 1 退出；debug 和 release 均会发生。

现在解析器在构建 AST 的过程中限制递归深度，并在每步构造后检查 AST 深度。异常请求返回结构化 `limit_exceeded`，同批前后正常请求仍有结果；单次查询返回诊断并以状态码 2 退出，不再崩溃。自动测试覆盖邮件中的三项批次、单次查询、深层括号表达式和深度临界值，debug／release 均运行。旧 0.1.1 版本保留供历史回溯。

## 限制与安全边界

默认限制为：表达式 16,384 个字符、AST 深度 256、执行步数 1,000,000、累计产生的结果元素 100,000 个。自定义限制须为有效值，AST 深度上限为 256；批量模式最多 10,000 个请求，CLI 最多读取 16 MiB，执行严格 UTF-8 解码并接受可选的 UTF-8 BOM。

0.1.3 还限制执行调用深度为 128，并用非递归遍历检查 JSON 输入与结果：深度不超过 256（根节点为 0）、展开节点不超过 1,000,000、保守输出估算不超过 16 Mi 个 UTF-16 单元。批次成功响应共享 500,000 节点和 8 Mi 单元预算，另行预留错误响应空间。超出剩余预算的请求返回该项错误，后续小请求仍继续执行。批次包装层也计入深度。详见 [资源限制说明](docs/resource-limits.md)。

当前版本 [0.1.4 已发布到 Mooncakes](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.4)，并从全新消费者项目完成 debug/release 安装调用验证；变更记录见 [CHANGELOG.md](CHANGELOG.md)。

库本身不执行文件或网络 I/O。Node.js 仅用于 CLI 的文件、标准流和进程适配。0.1.x 严格实现 JMESPath 规范，不加入自定义查询扩展，以保持与其他合规实现之间的结果可移植性。

## 十月继续完善的内容（0.1.3）

本次重新检查时，复现了 0.1.2 中另一个栈溢出：**255 层 `to_array(...)` 嵌套函数**能通过语法树检查，但调试版执行器会崩溃。现在执行器在继续调用前检查深度，返回结构化 `limit_exceeded`。

连续 `[@,@]` 管道只复制少量引用，却可能生成指数膨胀的 JSON 输出。现在按实际展开次数检查结果；JSON 相等比较改为非递归遍历并计入执行预算；`join` 在拼接前检查长度；对象合并在写入前检查结果预算；批次成功响应也有累计预算。非有限数值返回 `invalid_value`，避免生成无法解析的 JSON。

验证入口 `node scripts/verify.mjs` 包含零警告检查、37 项单元测试、三个真实使用场景，以及**每种构建模式**的 20 组边界/隔离检查和 256 组固定随机语法输入。恶意输入子进程都有超时与堆内存限制。官方合规测试同时核对结果和准确错误类型，分别跑 debug、release；Windows、Ubuntu CI 保存可下载的 JSON 验收记录。详见 [验收证据](docs/acceptance.md) 与 [参赛状态](docs/competition.md)。初审通过和技术验证不等于终审通过。

## 0.1.4：补齐空值语义和上手说明

进一步审查发现了固定官方测试集没有覆盖的边界：空值输入的多选列表／对象应返回
`null`；子表达式左侧缺失时，右侧函数仍应执行。例如 `{}` 上的
`missing.not_null(@, 'fallback')` 现在正确返回 `"fallback"`。
新增回归覆盖空值投影、`map` 保留项数、错误传递及非空假值，并保留已有资源限制。

快速开始已改为仓库内真实存在的文件；完整库示例加入两种构建模式的验证；
PowerShell 场景脚本可以从仓库外运行。详见 [使用约定](docs/usage.md)、
[维护说明](CONTRIBUTING.md) 和 [验收证据](docs/acceptance.md)。

## 工程结构与职责

- `lexer.mbt`：带位置的 Unicode 词法分析
- `parser.mbt`：Pratt 解析器和投影边界建模
- `evaluator.mbt`：查询执行与资源计数
- `functions.mbt`：标准函数及表达式引用
- `api.mbt`：公开库接口和批量接口
- `json_safety.mbt`、`equality.mbt`：输出展开检查与非递归 JSON 比较
- `cli/`、`cmd/main/`：命令行解析与宿主适配
- `examples/`：三组验收场景
- `scripts/`：本地验证、官方合规测试和 PowerShell 入口
- `docs/`：架构、合规与发布证据

## 原创、参考与许可证

MoonJMES 是依据 JMESPath 公开规范独立实现的项目，没有包含其他 JMESPath 实现的源代码。官方测试向量只在验证时从固定提交下载到操作系统临时目录，不进入源码包或发布产物。详情见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

项目采用 Apache-2.0 许可证。

面向参赛信息整理的中文项目介绍见 [docs/project-introduction.zh-CN.md](docs/project-introduction.zh-CN.md)。
