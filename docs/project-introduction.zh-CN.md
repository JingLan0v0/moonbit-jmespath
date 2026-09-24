# MoonJMES 项目介绍与申报参考

> 本文用于整理已验证的项目信息和辅助本人复核。若赛事表单要求申报书必须由参赛者本人撰写，请在实际运行项目并理解技术方案后，用自己的语言完成正式提交。

**类型：** 月度新项目申报　**方向：** 开发者工具（兼具数据处理用途）  
**仓库：** https://github.com/JingLan0v0/moonbit-jmespath  
**Mooncakes：** https://mooncakes.io/docs/JingLan0v0/jmespath

## 项目简介与价值

MoonJMES 是用 MoonBit 原生实现的 JMESPath JSON 查询引擎和命令行工具。使用者可以用一条表达式从嵌套 JSON 中完成筛选、投影、排序和结构重组，用于处理 API 响应、云资源清单、审计记录和配置文件，无需为每一种数据重复编写遍历与判空代码，也无需把数据发送到外部服务。

JMESPath 具有公开的语言规范和跨语言官方测试集，适合作为稳定的数据查询接口。MoonBit 生态中已有通用 JSON 工具和 jq 风格工具；MoonJMES 聚焦 JMESPath 规范兼容、可复用的预编译表达式、逐项隔离的批处理和受限执行。项目启动时对 Mooncakes 的检索没有发现同规范的 JMESPath 实现，但这一结论只代表当时的检索结果。

## 预期使用场景

1. **云资源清单：** 平台工程师把云平台导出的实例 JSON 交给 MoonJMES，用表达式筛选生产环境中正在运行的实例，并只输出实例 ID 和可用区，供容量检查和故障排查使用。
2. **部署策略审计：** 发布负责人查询一批部署判定记录，提取所有被拒绝的服务及对应原因码；批量模式会为错误查询单独返回结构化错误，不影响同批次的其他结果，便于自动化流水线继续汇总报告。
3. **成本报表：** 成本管理人员按 `monthly_cost` 对服务排序，并重组为只包含服务名和月度成本的稳定 JSON，直接交给报表或仪表盘，避免在每个脚本中重复实现排序和字段选择。

## 核心功能与实现

- MoonBit 实现 Unicode 词法分析、Pratt 语法解析、不可变 AST、投影语义、受限执行器和标准函数注册表。
- 支持字段、索引、切片、通配、扁平化、过滤、管道、比较、布尔表达式、多选结构及表达式引用。
- 实现标准标量、集合、转换和高阶函数，包括 `map`、`sort_by`、`min_by` 和 `max_by`。
- 提供 `compile`、`search`、`search_json`、`search_batch` 等库接口，以及文件、标准输入、紧凑输出和批量模式 CLI。
- 批量查询逐项返回结果或稳定错误码；表达式长度、AST 深度、执行步数、结果数量、批量规模和 CLI 输入大小均有明确限制。

核心查询引擎全部由 MoonBit 实现，Node.js 只承担 CLI 的文件、标准流和进程适配。项目在固定上游版本上通过 892/892 项 JMESPath 官方合规测试，同时提供本地测试、三组可运行场景及 Windows/Linux GitHub Actions。

## 交付与边界

当前交付版本为 `JingLan0v0/jmespath@0.1.1`，已经发布到 Mooncakes，并在独立消费者项目中完成安装、编译和真实 API 调用。仓库包含 MoonBit 库、CLI、三组场景、固定预期输出、中英文 README、架构说明、合规记录、PowerShell 工作流和 Apache-2.0 许可证。

0.1.x 严格实现 JMESPath 规范，不加入自定义查询扩展。库本身不负责网络请求、数据库连接或文件写回；CLI 输入限制为 16 MiB，默认表达式上限 16,384 个字符、AST 深度 256、执行步数 1,000,000、结果数量 100,000。当前发布目标为 JS，不提供流式 JSON 解析或跨请求共享可变状态。

## 原创、参考与许可

MoonJMES 是依据 [JMESPath 公开规范](https://jmespath.org/specification.html)独立完成的 MoonBit 实现，不是对其他语言实现源码的翻译，也未复制其他 JMESPath 库的代码。验证脚本会从固定提交下载 [jmespath.test](https://github.com/jmespath/jmespath.test) 官方测试向量到操作系统临时目录，这些向量不会进入源码包或发布产物。参考来源和验证边界记录在 `THIRD_PARTY_NOTICES.md` 与 `docs/conformance.md` 中，项目采用 Apache-2.0 许可证。
