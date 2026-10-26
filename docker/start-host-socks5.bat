@echo off
REM Start host SOCKS5 so ARTEX containers can dial Windows 127.0.0.x addresses.
cd /d "%~dp0"
echo Starting host-socks5 on 0.0.0.0:11080 ...
python "%~dp0host-socks5.py"