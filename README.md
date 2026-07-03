# Snell Server Docker

[English](README.en.md)

面向 Linux server/VPS 的 Snell Server Docker 镜像。

## 特性

- 仅面向 Linux server/VPS
- 推荐使用 `host` 网络模式
- 不依赖挂载配置文件
- 使用环境变量生成运行配置
- 运行容器时必须启用 Docker init：`docker run --init` 或 Compose `init: true`

## 快速开始

### docker run

```shell
docker run -d \
  --name snell \
  --init \
  --network host \
  -e PSK=your_secure_password \
  angribot/snell:latest
```

### docker compose

```yaml
services:
  snell:
    image: angribot/snell:latest
    container_name: snell
    restart: always
    init: true
    network_mode: host
    environment:
      PSK: your_secure_password
```

## 环境变量

| 变量 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `PSK` | 是 | 无 | 共享密钥，长度必须为 12-255 字节 |
| `PORT` | 否 | `2345` | Snell 监听端口 |
| `MODE` | 否 | `default` | 可选值：`default`、`unshaped`、`unsafe-raw` |
| `DNS` | 否 | 无 | 逗号分隔的 DNS 列表 |
| `DNS_IP_PREFERENCE` | 否 | 无 | 可选值：`default`、`prefer-ipv4`、`prefer-ipv6`、`ipv4-only`、`ipv6-only` |
| `EGRESS_INTERFACE` | 否 | 无 | 绑定 Snell 出站流量的网卡名 |
| `LOG_LEVEL` | 否 | `notify` | 传给 `snell-server -l` 的日志级别 |

## 兼容与废弃

以下旧环境变量仍然兼容，但启动时会打印废弃提示：

- `DNSIP` -> `DNS_IP_PREFERENCE`
- `EGRESS` -> `EGRESS_INTERFACE`
- `LOG` -> `LOG_LEVEL`

这些旧变量将在 Snell Server v6 正式版发布时移除支持。

`VERSION` 不再作为运行时配置项生效。Snell 版本在镜像构建阶段决定。

## 版本说明

- Git tag 触发的镜像构建要求 tag 名与内置 `SNELL_VERSION` 完全一致
- 如果两者不一致，构建会失败
- 在 Snell Server v6 正式版发布前，`latest` 指向最近一次通过校验的测试版镜像

## 网络说明

- `host` 模式是官方推荐路径
- bridge / 端口映射不是主支持场景
- 尤其是 IPv6 场景下，优先使用 `host` 模式
