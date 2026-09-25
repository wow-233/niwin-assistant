# 第三方项目参考说明

泥win助手的代码和视觉资产在本仓库中独立实现。开发过程中调研了以下开源项目的公开设计与导入思路：

- [拾光课程表](https://github.com/XingHeYuZhuan/shiguangschedule)（Apache-2.0）：参考可扩展教务适配、课表个性化与导入预览的产品思路。
- [拾光课程表适配脚本仓库](https://github.com/XingHeYuZhuan/shiguang_warehouse)（MIT，Copyright (c) 2025 星河欲转）：`lib/services/wzu_sync_script.dart` 中正方通用网格/列表专用路径改写自 `resources/zhengfang_jiaowu/zhengfang_01.js` 的 DOM 字段顺序与视图判断逻辑；原项目 MIT 许可证见下文。
- [Sleepy](https://github.com/lingion/sleepy)（GPL-3.0）：参考按教务协议拆分解析器、导入前预览、本地优先和提醒恢复的产品思路。
- [下节啥课](https://github.com/baoozak/timetable)（MIT）：参考新版正方通过同源课表接口读取 `kbList`，以及用 DOM 矩阵处理 `rowspan/colspan` 的解析思路。

本说明不是对上述项目的背书，也不表示本应用与温州大学或上述项目存在官方关系。若后续直接引入任何第三方源码或资源，应在合并时保留其版权与许可证文本，并在这里逐项记录文件路径和修改内容。

## 拾光适配脚本仓库 MIT 许可证

Copyright (c) 2025 星河欲转

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## 协议与交互调研

- [quzhi-lite / 趣智轻享](https://github.com/wzk-chi/quzhi-lite)：用于了解公开可观察的登录、蓝牙发现、设备查询及热水启停交互。该仓库未见明确许可证，因此泥win助手没有复制或打包其源码与资源，而是独立实现所需的 Android/Flutter 流程。
- [zfn_api](https://github.com/openschoolcn/zfn_api)：用于核对正方教务“学生学业情况”的分类节点及课程明细请求方式；泥win助手独立实现页面内同源读取与卡片展示。
