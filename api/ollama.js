// Vercel Serverless函数作为Ollama API的代理
// 用于解决HTTPS前端调用HTTP后端的问题

// 导入所需模块
const https = require('https');
const http = require('http');
const { URL } = require('url');

// Ollama API的地址和端口
const OLLAMA_HOST = '36.133.18.27';
const OLLAMA_PORT = '11434';
const MODEL_NAME = 'deepseek-r1:70b';

// 处理请求的主函数
module.exports = async (req, res) => {
  // 设置CORS头，明确指定允许的域名
  res.setHeader('Access-Control-Allow-Origin', 'https://hxh.paydn.cn');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  // 处理预检请求 - 确保正确响应OPTIONS请求
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return; // 确保在这里返回，不继续处理
  }

  // 只允许POST请求
  if (req.method !== 'POST') {
    return res.status(405).json({ error: '只支持POST请求' });
  }

  try {
    // 获取请求体
    const body = req.body;
    
    // 如果是/api/generate路径，转发到Ollama的generate接口
    if (req.url.includes('/api/generate')) {
      // 确保body包含必要的字段
      if (!body || !body.prompt) {
        return res.status(400).json({ error: '请求缺少必要的参数' });
      }
      
      // 准备发送到Ollama的请求数据
      const ollamaRequestData = {
        model: MODEL_NAME,
        prompt: body.prompt,
        stream: false,
        options: body.options || {}
      };

      // 发送请求到Ollama API
      const ollamaResponse = await sendRequestToOllama('/api/generate', ollamaRequestData);
      
      // 返回Ollama的响应
      return res.status(200).json(ollamaResponse);
    } else {
      // 其他API端点的处理
      return res.status(404).json({ error: '未找到请求的API端点' });
    }
  } catch (error) {
    console.error('代理请求失败:', error);
    return res.status(500).json({ error: `代理请求失败: ${error.message}` });
  }
};

// 发送请求到Ollama API的函数
async function sendRequestToOllama(path, data) {
  return new Promise((resolve, reject) => {
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
      let responseData = '';
      
      // 接收数据
      response.on('data', (chunk) => {
        responseData += chunk;
      });
      
      // 所有数据接收完毕
      response.on('end', () => {
        try {
          // 尝试解析响应为JSON
          const parsedData = JSON.parse(responseData);
          resolve(parsedData);
        } catch (error) {
          // 如果不是有效的JSON，直接返回原始响应
          resolve({ response: responseData });
        }
      });
    });
    
    // 处理请求错误
    request.on('error', (error) => {
      reject(error);
    });
    
    // 发送请求数据
    request.write(JSON.stringify(data));
    request.end();
  });
} 