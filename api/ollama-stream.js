// Vercel Serverless函数 - 支持流式响应的Ollama API代理
// 专门用于处理流式返回的API调用

// 导入所需模块
const http = require('http');

// Ollama API的地址和端口
const OLLAMA_HOST = '36.133.18.27';
const OLLAMA_PORT = '11434';
const MODEL_NAME = 'deepseek-r1:70b';

// 允许的域名列表
const allowedOrigins = [
    'https://hxh.paydn.cn',
    'http://localhost:5000',
    'http://127.0.0.1:5000',
    'https://hxhwork.xyz'
];

// 处理请求的主函数
module.exports = async (req, res) => {
  // 获取请求的Origin
  const origin = req.headers.origin;
  
  // 如果请求的Origin在允许列表中，设置对应的CORS头
  if (origin && allowedOrigins.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  
  // 设置其他CORS头
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  // 处理预检请求
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // 只允许POST请求
  if (req.method !== 'POST') {
    return res.status(405).json({ error: '只支持POST请求' });
  }

  try {
    // 获取请求体
    const body = req.body;
    
    // 确保body包含必要的字段
    if (!body || !body.prompt) {
      return res.status(400).json({ error: '请求缺少必要的参数' });
    }
    
    // 准备发送到Ollama的请求数据
    const ollamaRequestData = {
      model: MODEL_NAME,
      prompt: body.prompt,
      stream: true, // 启用流式响应
      options: body.options || {}
    };

    // 设置流式响应的头部
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    // 发送请求到Ollama API并流式返回响应
    await streamResponseFromOllama('/api/generate', ollamaRequestData, res);
    
    // 流式响应完成后结束
    return res.end();
  } catch (error) {
    console.error('流式代理请求失败:', error);
    
    // 如果已经开始发送流式响应，发送错误事件
    if (res.headersSent) {
      res.write(`data: ${JSON.stringify({ error: error.message })}\n\n`);
      return res.end();
    } else {
      // 否则返回常规错误响应
      return res.status(500).json({ error: `代理请求失败: ${error.message}` });
    }
  }
};

// 流式转发Ollama响应的函数
async function streamResponseFromOllama(path, data, responseStream) {
  return new Promise((resolve, reject) => {
    // 设置超时处理，确保不超过Vercel限制
    const timeoutId = setTimeout(() => {
      // 发送超时通知并结束处理
      responseStream.write(`data: ${JSON.stringify({
        done: true,
        response: "响应时间过长，已断开连接。请尝试发送更简短的问题或联系管理员升级服务。",
        model: data.model,
        created_at: new Date().toISOString()
      })}\n\n`);
      
      resolve(); // 结束Promise
    }, 55000); // 设置为55秒，留出一些缓冲时间
    
    // 准备请求选项
    const options = {
      hostname: OLLAMA_HOST,
      port: OLLAMA_PORT,
      path: path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      }
    };

    // 创建请求
    const request = http.request(options, (response) => {
      // 处理Ollama API响应
      response.on('data', (chunk) => {
        // 将每个数据块作为SSE事件发送
        responseStream.write(`data: ${chunk.toString()}\n\n`);
      });
      
      // 响应结束
      response.on('end', () => {
        clearTimeout(timeoutId); // 清除超时
        resolve();
      });
    });
    
    // 处理请求错误
    request.on('error', (error) => {
      clearTimeout(timeoutId); // 清除超时
      reject(error);
    });
    
    // 发送请求数据
    request.write(JSON.stringify(data));
    request.end();
  });
} 