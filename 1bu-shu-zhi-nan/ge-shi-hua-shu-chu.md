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

| json path |
| :--- |


| Function | Description | Example | Result |
| :--- | :--- | :--- | :--- |
| text | the plain text | kind is {.kind} | kind is List |
| @ | the current object | {@} | the same as input |
| . or \[\] | child operator | {.kind} or {\[‘kind’\]} | List |
| .. | recursive descent | {..name} | 127.0.0.1 127.0.0.2 myself e2e |
| \* | wildcard. Get all objects | {.items\[\*\].metadata.name} | \[127.0.0.1 127.0.0.2\] |
| \[start:end :step\] | subscript operator | {.users\[0\].name} | myself |
| \[,\] | union operator | {.items\[\*\]\[‘metadata.name’, ‘status.capacity’\]} | 127.0.0.1 127.0.0.2 map\[cpu:4\] map\[cpu:8\] |
| ?\(\) | filter | {.users\[?\(@.name==”e2e”\)\].user.password} | secret |
| range, end | iterate list | {range .items\[\*\]}\[{.metadata.name}, {.status.capacity}\] {end} | \[127.0.0.1, map\[cpu:4\]\] \[127.0.0.2, map\[cpu:8\]\] |
| ”” | quote interpreted string | {range .items\[\*\]}{.metadata.name}{“\t”}{end} | 127.0.0.1 127.0.0.2 |

Below are some examples using jsonpath:

```
$ kubectl get pods -o json
$ kubectl get pods -o=jsonpath='{@}'
$ kubectl get pods -o=jsonpath='{.items[0]}'
$ kubectl get pods -o=jsonpath='{.items[0].metadata.name}'
$ kubectl get pods -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.startTime}{"\n"}{end}'
```



