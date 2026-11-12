# MoonJMES

[English](README.md)

MoonJMES 是用 MoonBit 实现的 JMESPath JSON 查询库和命令行工具。可以筛选记录、提取字段、
投影嵌套数据和排序报表。项目支持 JS 后端，命令行工具由 Node.js 运行。

已发布版本为 **0.1.20**。[Mooncakes 包](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.20) · [变更记录](CHANGELOG.md)

## 安装库

在已有 MoonBit 模块中安装指定版本。

```sh
moon add JingLan0v0/jmespath@0.1.20
```

最小可执行示例的 `moon.pkg` 如下。

```moonbit
import {
  "JingLan0v0/jmespath" @jmespath,
}

pkgtype(kind: "executable")
```

在同一包目录创建 `main.mbt`。

```moonbit
fn main raise {
  let input = @jmespath.parse_json_bounded("{\"items\":[{\"name\":\"Ada\"}]}")
  let query = @jmespath.compile("items[*].name")
  println(@jmespath.stringify_bounded(query.search(input)))
}
```

在可执行包中运行 `moon run . --target js`，输出为 `["Ada"]`。仓库也提供包含自定义限制、
查询复用和错误处理的完整程序。[库示例](examples/library/main.mbt) · [API 指南](docs/usage.md)

## 从源码运行 CLI

使用固定版本 MoonBit `0.10.20+65efd5b93` 和 Node.js `24.14.0`。MoonBit `0.10.14`
等旧版本无法编译当前源码。[工具链配置](toolchain.json) · [官方安装说明](https://www.moonbitlang.com/download/)

```sh
git clone https://github.com/JingLan0v0/moonbit-jmespath.git
cd moonbit-jmespath
moon run cmd/main --target js -- --compact "instances[?state == 'running'].id" examples/cloud-inventory.json
```

预期输出为 `["i-101","i-102","i-104"]`。输入路径填 `-` 可以从标准输入读取 JSON。
Windows 可以用 `scripts/moon.ps1` 选择本地固定工具链。
[PowerShell 命令](examples/README.md#windows-powershell) · [CLI 用法](docs/usage.md#cli-automation)

## 运行带断言的演示

```sh
node examples/demo.mjs
```

| 场景 | 查询结果 |
| --- | --- |
| 云主机清单 | 正在运行的生产实例 ID 和可用区 |
| 部署策略检查 | 被阻止的服务及嵌套原因代码 |
| 费用报表 | 按月度费用升序排列的服务 |

演示会核对三组已提交的预期 JSON，也会检查快速入门查询和一个依次返回
`before`、`limit_exceeded`、`after` 的批次。加上 `--release` 可运行发布构建。
[输入、查询与预期结果](examples/README.md)

批量输入是由 `{"expression":"…","data":…}` 请求组成的 JSON 数组。CLI 接受批次后
以状态码 0 退出，每项分别返回 `ok` 和结果或错误。若批次外层 JSON 损坏，
整次调用以状态码 2 退出，stdout 为空。[批量接口与错误约定](docs/usage.md#cli-automation)

## 限制与兼容性

默认表达式上限是 16,384 个 Unicode 标量，AST 深度上限 256，执行预算 100 万步，
结果累计生成元素上限 10 万。执行器活动调用深度上限为 128。CLI 最多读取 16 MiB 输入，
批次最多接受 10,000 个请求。JSON 输入和输出都有形状与展开检查。[资源限制](docs/resource-limits.md)

函数错误偏移从 0 开始按 Unicode 标量计数。返回结果可能共享调用方输入的集合，
每次执行已编译查询都会使用独立状态。[诊断与数据共享约定](docs/usage.md)

## 验证源码

```sh
node scripts/verify.mjs
```

Windows 和 Ubuntu CI 使用同一命令。调试版和发布版分别运行 79 项单测、
892 条固定版本的 JMESPath 官方用例、演示及资源边界回归。Windows 还检查
PowerShell。验证结果写入 `_build/verification-summary.json`。
[验收设置](CONTRIBUTING.md#verification) · [GitHub Actions](https://github.com/JingLan0v0/moonbit-jmespath/actions/workflows/ci.yml)

验收记录按提交保存测试结果、历史修复、归档检查和新项目安装证据。
[验收记录](docs/acceptance.md) · [性能基准](docs/performance.md) · [参赛项目介绍](docs/project-introduction.zh-CN.md)

## 许可证与参考资料

MoonJMES 依据 JMESPath 公开规范独立实现。固定版本的上游测试向量在验证时下载。
项目采用 Apache-2.0 许可证。[许可证](LICENSE) · [第三方说明](THIRD_PARTY_NOTICES.md)
