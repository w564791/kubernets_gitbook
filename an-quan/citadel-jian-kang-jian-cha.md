本次任务为Citadel启用kubernetes状态检查,请注意,这是Alpha功能.

默认情况下,istio部署的时候,CCitadel未启用健康检查功能,目前,健康检查功能通过定期向API发送CSR请求来检测Citadel的CSR签名鼓舞的故障,很快就会有更多的健康和检查功能

Citadel包含一个探针,可以定期检查Citadel的状态,如果Citadel是健康的,改探针客户端更新修改时间的健康状态文件\(该文件为空\),否则,其什么都不做,Citadel依靠K8S的liveness和readiness探针来检查的时间间隔和健康状态文件,如果文件未在一段时间内更新,则触发探测并重启Citadel容器


