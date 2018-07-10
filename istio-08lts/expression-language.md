# 功能

| Operator/Function | Definition                                                   | Example                                                      | Description                                                  |
| ----------------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| `==`              | Equals                                                       | `request.size == 200`                                        |                                                              |
| `!=`              | Not Equals                                                   | `request.auth.principal != "admin"`                          |                                                              |
| `\|\|`            | Logical OR                                                   | `(request.size == 200) \|\| (request.auth.principal == “admin”)` |                                                              |
| `&&`              | Logical AND                                                  | `(request.size == 200) && (request.auth.principal == "admin")` |                                                              |
| `[ ]`             | Map Access                                                   | `request.headers["x-id"]`                                    |                                                              |
| `\|`              | First non empty                                              | `source.labels[“app”] \| source.labels[“svc”] \| “unknown”`  |                                                              |
| `match`           | Glob match                                                   | `match(destination.service, "*.ns1.svc.cluster.local")`      | Matches prefix or suffix based on the location of `*`        |
| `email`           | Convert a textual e-mail into the `EMAIL_ADDRESS`type        | `email("awesome@istio.io")`                                  | Use the `email` function to create an `EMAIL_ADDRESS`literal. |
| `dnsName`         | Convert a textual DNS name into the `DNS_NAME`type           | `dnsName("www.istio.io")`                                    | Use the `dnsName` function to create a `DNS_NAME`literal.    |
| `ip`              | Convert a textual IPv4 address into the `IP_ADDRESS` type    | `source.ip == ip("10.11.12.13")`                             | Use the `ip` function to create an `IP_ADDRESS` literal.     |
| `timestamp`       | Convert a textual timestamp in RFC 3339 format into the `TIMESTAMP` type | `timestamp("2015-01-02T15:04:35Z")`                          | Use the `timestamp` function to create a `TIMESTAMP`literal. |
| `uri`             | Convert a textual URI into the `URI` type                    | `uri("http://istio.io")`                                     | Use the `uri` function to create a `URI` literal.            |
| `.matches`        | Regular expression match                                     | `"svc.*".matches(destination.service)`                       | Matches `destination.service` against regular expression pattern `"svc.*"`. |
| `.startsWith`     | string prefix match                                          | `destination.service.startsWith("acme")`                     | Checks whether `destination.service` starts with `"acme"`.   |
| `.endsWith`       | string postfix match                                         | `destination.service.endsWith("acme")`                       | Checks whether `destination.service` ends with `"acme"`.     |

# 举例

| Expression                                                   | Return Type | Description                                                  |
| ------------------------------------------------------------ | ----------- | ------------------------------------------------------------ |
| `request.size \| 200`                                        | **int**     | `request.size` if available, otherwise 200.                  |
| `request.headers["X-FORWARDED-HOST"] == "myhost"`            | **boolean** |                                                              |
| `(request.headers["x-user-group"] == "admin") \|\| (request.auth.principal == "admin")` | **boolean** | True if the user is admin or in the admin group.             |
| `(request.auth.principal \| "nobody" ) == "user1"`           | **boolean** | True if `request.auth.principal` is “user1”, The expression will not error out if `request.auth.principal` is missing. |
| `source.labels["app"]=="reviews" && source.labels["version"]=="v3"` | **boolean** | True if app label is reviews and version label is v3, false otherwise. |

