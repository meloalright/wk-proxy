# WK Proxy

`WKWebview 离线化加载 Web 资源解决方案`

`思路: 使用 NSURLProtocol 拦截请求转发到本地。`

## Run [Proxy-Browser](./proxy-browser)

`Open xcworkspace + Run app`

## Run Static Service

`Create web static service`

```shell
$ http-server ./zip-in-vue/dist/ -p 3233
```

`Create another bash + Create zip source static service`

```shell
$ http-server ./zip-in-vue -p 3238
```
