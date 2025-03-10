# Vercel代理解决方案 - HTTPS前端调用HTTP后端

这个解决方案通过Vercel Serverless函数实现了从HTTPS前端安全调用HTTP后端API的能力。

## 功能特点

- 使用Vercel Serverless函数作为反向代理
- 支持普通API调用和流式API响应
- 解决HTTPS前端无法直接访问HTTP后端的混合内容限制
- 提供CORS头处理，确保跨域请求正常工作

## 项目结构

```
├── api/
│   ├── ollama.js         # 普通API代理
│   └── ollama-stream.js  # 流式响应API代理
├── index.html            # 前端页面
├── vercel.json           # Vercel配置
└── README.md             # 项目说明
```

## 部署步骤

1. 克隆此仓库到本地
2. 登录Vercel账户并连接仓库
3. 部署项目到Vercel
4. 在前端代码中更新Vercel应用的URL

## 使用方法

前端代码已更新为使用Vercel代理API，而不是直接调用HTTP后端。API调用将通过以下路径:

- 普通API调用: `https://your-vercel-app.vercel.app/api/ollama/generate`
- 流式API调用: `https://your-vercel-app.vercel.app/api/ollama-stream/generate`

## 注意事项

- Vercel免费版Serverless函数超时时间为10秒，Pro版为60秒。如需更长响应时间，请升级账户。
- 代理服务设置了CORS头为`*`，生产环境应考虑设置为特定域名，增强安全性。
- 如需调整超时设置，请在vercel.json文件中修改maxDuration参数。

## 故障排除

如遇到问题，请检查:

1. 确认Ollama API服务是否可访问
2. 检查Vercel日志中是否有错误信息
3. 确认前端代码中的Vercel URL是否正确

---

部署时请替换`https://git-work.vercel.app`为您自己的Vercel应用URL。 