### 格式化输出 {#格式化输出}

要以特定的格式向终端窗口输出详细信息，可以在kubectl命令中添加-o或者-output标志。

| 输出格式 | 描述 |
| :--- | :--- |
| -o=custom-columns=&lt;spec&gt; | 使用逗号分隔的自定义列列表打印表格 |
| -o=custom-columns-file=&lt;filename&gt; | 使用 文件中的自定义列模板打印表格 |
| -o=json | 输出 JSON 格式的 API 对象 |
| -o=jsonpath=&lt;template&gt; | 打印[jsonpath](https://kubernetes.io/docs/user-guide/jsonpath)表达式中定义的字段 |
| -o=jsonpath-file=&lt;filename&gt; | 打印由 文件中的[jsonpath](https://kubernetes.io/docs/user-guide/jsonpath)表达式定义的字段 |
| -o=name | 仅打印资源名称 |
| -o=wide | 以纯文本格式输出任何附加信息，对于 Pod ，包含节点名称 |
| -o=yaml | 输出 YAML 格式的 API 对象 |



