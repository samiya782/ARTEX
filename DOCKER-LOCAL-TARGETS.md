# Docker / 本机 127.0.0.x 通路

## 一键启动（推荐）

SOCKS 必须跑在 **Windows 宿主机**（才能拨 `127.0.0.2` / `127.0.0.3`），不能只放进 Linux 镜像里。

用仓库根目录脚本会先起 SOCKS 再起 compose：

```powershell
cd C:\Users\HP\ARTEX-mssky
.\start-stack.ps1 -Build
# 或
.\start-stack.bat
```

停止：

```powershell
.\stop-stack.ps1
```

## 组件

| 组件 | 位置 | 作用 |
|------|------|------|
| 宿主机 SOCKS5 | `docker/host-socks5.py`（`:11080`） | 在 Windows 上按原目标拨 `127.0.0.x` |
| 容器导流 | `artex:host-loopback` + redsocks | 把容器内 `127.0.0.0/8` TCP 导到宿主机 SOCKS |
| 编排 | `docker-compose.yml` + `docker-compose.override.yml` | ARTEX + Postgres |

## 自适应

整段 `127.0.0.0/8`（除 8787/8788）同一条链路，无需按地址配置：

- `https://127.0.0.2/`、`http://127.0.0.3:90/`、`https://127.0.0.3:10009/`
- 以及以后的 `https://127.0.0.1:23303/` 等

## 说明

- 只处理 TCP。
- 仅 `docker compose up` 而**不起**宿主机 SOCKS 时，容器里 `127.0.0.2/3` 会失败；请用 `start-stack.ps1`。
- 二改目前在本机，默认未 push GitHub。