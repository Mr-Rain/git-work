# 脚本名称: set_process_priority.ps1
# 描述: 为无畏契约反作弊检测进程设置CPU优先级和亲和性
# 作者: 不离不弃的夜雨
# 版本: 1.0.2
# 最后更新: 2024-03-05
# 
# 使用方法:
# 1. 使用 run_as_admin.bat 运行此脚本
# 2. 脚本会自动检测CPU核心数并分配最后两个核心（一般靠后的为小核）
# 3. 将 SGuard64.exe 和 SGuardSvc64.exe 的优先级设置为"低"
# 4. 设置这些进程在最后两个CPU核心上运行
#
# 返回值:
# - 0: 所有操作成功完成
# - 1: 部分或全部操作失败

# 检查管理员权限
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to get administrator privileges. Please run the script as administrator manually."
        exit 1
    }
    exit
}

# 设置错误处理
$ErrorActionPreference = "Stop"

# 设置控制台编码为UTF8
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
}
catch {
    Write-Error "Failed to set encoding: $($_.Exception.Message)"
    exit 1
}

# 将十六进制字符串转换为中文字符的函数
function ConvertTo-Chinese {
    param(
        [Parameter(Mandatory=$true)]
        [string]$hex
    )
    try {
        $bytes = [byte[]]($hex -split '(..)' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })
        return [System.Text.Encoding]::UTF8.GetString($bytes)
    }
    catch {
        Write-Error "Failed to convert Chinese characters: $($_.Exception.Message)"
        exit 1
    }
}

# 定义中文消息
$messages = @{
    ScriptStart = ConvertTo-Chinese "E7A88BE5BA8FE5BC80E5A78BE689A7E8A18C"          # 程序开始执行
    DetectedCores = ConvertTo-Chinese "E6A380E6B58BE588B0435055E6A0B8E5BF83E695B0"  # 检测到CPU核心数
    AssignCores = ConvertTo-Chinese "E5B086E58886E9858DE8BF9BE7A88BE588B0E6A0B8E5BF83"  # 将分配进程到核心
    And = ConvertTo-Chinese "E5928C"                                                 # 和
    Processing = ConvertTo-Chinese "E6ADA3E59CA8E5A484E79086"                       # 正在处理
    Success = ConvertTo-Chinese "E68890E58A9F"                                      # 成功
    Error = ConvertTo-Chinese "E99499E8AFAF"                                        # 错误
    SetPriorityLow = ConvertTo-Chinese "E5B7B2E8AEBEE7BDAEE4B8BAE4BD8EE4BC98E58588E7BAA7"  # 已设置为低优先级
    SetPriorityFailed = ConvertTo-Chinese "E8AEBEE7BDAEE4BC98E58588E7BAA7E5A4B1E8B4A5"  # 设置优先级失败
    SetAffinityCore = ConvertTo-Chinese "E5B7B2E8AEBEE7BDAE435055E4BAB2E5928CE680A7E588B0E6A0B8E5BF83"  # 已设置CPU亲和性到核心
    SetAffinityFailed = ConvertTo-Chinese "E8AEBEE7BDAE435055E4BAB2E5928CE680A7E5A4B1E8B4A5"  # 设置CPU亲和性失败
    ProcessNotFound = ConvertTo-Chinese "E69CAAE689BEE588B0E8BF9BE7A88B"          # 未找到进程
    Complete = ConvertTo-Chinese "E689A7E8A18CE5AE8CE68890"                        # 执行完成
    ScriptEnd = ConvertTo-Chinese "E7A88BE5BA8FE7BB93E69D9F"                      # 程序结束
}

# 设置日志文件路径
$logFile = Join-Path $PSScriptRoot "log.txt"
$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# 获取CPU核心数
try {
    $processorCount = (Get-WmiObject -Class Win32_ComputerSystem).NumberOfLogicalProcessors
    if ($null -eq $processorCount -or $processorCount -lt 2) {
        throw "Invalid CPU core count or less than 2 cores available"
    }
}
catch {
    Write-Error "Failed to get CPU information: $($_.Exception.Message)"
    exit 1
}

# 计算最后两个核心编号（从0开始）
$lastCore = $processorCount - 1
$secondLastCore = $processorCount - 2

# 计算CPU亲和性掩码
try {
    $lastCoreMask = [Math]::Pow(2, $lastCore)
    $secondLastCoreMask = [Math]::Pow(2, $secondLastCore)
}
catch {
    Write-Error "Failed to calculate CPU affinity masks: $($_.Exception.Message)"
    exit 1
}

# 初始化日志内容数组
$logContent = New-Object System.Collections.ArrayList

# 记录脚本启动和配置信息
$null = $logContent.Add("[$date] $($messages.ScriptStart)")
$null = $logContent.Add("$($messages.DetectedCores): $processorCount")
$null = $logContent.Add("$($messages.AssignCores) $secondLastCore $($messages.And) $lastCore")

# 定义进程配置
$processConfigs = @(
    @{
        Name = "SGuard64.exe"
        Mask = $lastCoreMask
        Core = $lastCore
    },
    @{
        Name = "SGuardSvc64.exe"
        Mask = $secondLastCoreMask
        Core = $secondLastCore
    }
)

# 初始化成功标志
$success = $true

# 处理每个配置
foreach ($config in $processConfigs) {
    $null = $logContent.Add("`n$($messages.Processing): $($config.Name)")
    
    try {
        $process = Get-Process -Name $config.Name.Replace(".exe", "") -ErrorAction SilentlyContinue
    }
    catch {
        $success = $false
        $null = $logContent.Add("  [$($messages.Error)] $($messages.ProcessNotFound): $($config.Name)")
        continue
    }
    
    if ($process) {
        try {
            $process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle
            $null = $logContent.Add("  [$($messages.Success)] $($messages.SetPriorityLow)")
        }
        catch {
            $success = $false
            $null = $logContent.Add("  [$($messages.Error)] $($messages.SetPriorityFailed): $($_.Exception.Message)")
        }
        
        try {
            $process.ProcessorAffinity = [IntPtr]::new($config.Mask)
            $null = $logContent.Add("  [$($messages.Success)] $($messages.SetAffinityCore) $($config.Core)")
        }
        catch {
            $success = $false
            $null = $logContent.Add("  [$($messages.Error)] $($messages.SetAffinityFailed): $($_.Exception.Message)")
        }
    }
    else {
        $success = $false
        $null = $logContent.Add("  [$($messages.Error)] $($messages.ProcessNotFound): $($config.Name)")
    }
}

# 记录完成信息
$null = $logContent.Add("`n$($messages.Complete)!")
$null = $logContent.Add("[$date] $($messages.ScriptEnd)")

# 将日志内容写入文件
try {
    $logContent | Out-File -FilePath $logFile -Encoding UTF8 -ErrorAction Stop
}
catch {
    Write-Error "Failed to write log file: $($_.Exception.Message)"
    exit 1
}

# 返回执行状态yes
exit ([int](!$success)) 