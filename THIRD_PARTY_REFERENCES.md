# 第三方项目参考说明

泥win助手的代码和视觉资产在本仓库中独立实现。开发过程中调研了以下开源项目的公开设计与导入思路：

- [拾光课程表](https://github.com/XingHeYuZhuan/shiguangschedule)（Apache-2.0）：参考可扩展教务适配、课表个性化与导入预览的产品思路。
- [Sleepy](https://github.com/lingion/sleepy)（GPL-3.0）：参考按教务协议拆分解析器、导入前预览、本地优先和提醒恢复的产品思路。
- [下节啥课](https://github.com/baoozak/timetable)（MIT）：参考新版正方通过同源课表接口读取 `kbList`，以及用 DOM 矩阵处理 `rowspan/colspan` 的解析思路。

本说明不是对上述项目的背书，也不表示本应用与温州大学或上述项目存在官方关系。若后续直接引入任何第三方源码或资源，应在合并时保留其版权与许可证文本，并在这里逐项记录文件路径和修改内容。
## 可选集成

- [quzhi-lite / 趣智轻享](https://github.com/wzk-chi/quzhi-lite)：实验性快捷入口，用来打开用户另行安装的 Android 客户端。泥win助手不内置其源码、账号凭据或 APK。
