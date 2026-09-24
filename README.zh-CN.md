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

主要入口包括 `compile`、`Compiled::search`、`search`、`search_json` 和 `search_batch`。

## PowerShell 使用方式

仓库提供 `scripts/moon.ps1`，会优先使用仓库旁边的固定 MoonBit 工具链，也可以回退到系统中的 `moon`：

```powershell
.\scripts\moon.ps1 check --target js
.\scripts\moon.ps1 test --target js
.\scripts\moon.ps1 run cmd/main --target js -- "instances[?state == 'running'].id" inventory.json
```

从标准输入查询：

```powershell
'{"items":[{"name":"A","price":9},{"name":"B","price":12}]}' |
  .\scripts\moon.ps1 run cmd/main --target js -- "items[?price >= `10`].name" -
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
.\scripts\moon.ps1 run cmd/main --target js -- --batch requests.json
```

每个返回项都包含 `ok: true` 和 `result`，或者 `ok: false` 和结构化 `error`。单个错误表达式不会丢弃同批次中的其他结果。

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
```

GitHub Actions 使用固定编译器版本，在 Windows 和 Ubuntu 上执行构建、测试、示例、接口一致性检查和全部官方合规用例。

## 限制与安全边界

默认限制为：表达式 16,384 个字符、AST 深度 256、执行步数 1,000,000、投影结果 100,000 个；批量模式最多 10,000 个请求，CLI 输入最多 16 MiB 并执行严格 UTF-8 解码。

库本身不执行文件或网络 I/O。Node.js 仅用于 CLI 的文件、标准流和进程适配。0.1.x 严格实现 JMESPath 规范，不加入自定义查询扩展，以保持与其他合规实现之间的结果可移植性。

## 工程结构

- `lexer.mbt`：带位置的 Unicode 词法分析
- `parser.mbt`：Pratt 解析器和投影边界建模
- `evaluator.mbt`：查询执行与资源计数
- `functions.mbt`：标准函数及表达式引用
- `api.mbt`：公开库接口和批量接口
- `cli/`、`cmd/main/`：命令行解析与宿主适配
- `examples/`：三组验收场景
- `scripts/`：本地验证、官方合规测试和 PowerShell 入口
- `docs/`：架构、合规与发布证据

## 原创、参考与许可证

MoonJMES 是依据 JMESPath 公开规范独立实现的项目，没有包含其他 JMESPath 实现的源代码。官方测试向量只在验证时从固定提交下载到操作系统临时目录，不进入源码包或发布产物。详情见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

项目采用 Apache-2.0 许可证。
