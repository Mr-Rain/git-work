# 脚本名称: set_process_priority.ps1
# 描述: 为无畏契约反作弊检测进程设置CPU优先级和亲和性
# 作者: 不离不弃的夜雨
# 版本: 1.0.4
# 最后更新: 2025-03-06
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
    LogHeader = ConvertTo-Chinese "E69C80E8BF91E58D81E6ACA1E6938DE4BD9CE8AEB0E5BD95"  # 最近十次操作记录
}

# Function to manage log rotation
function Update-LogHistory {
    param (
        [string]$logFile,
        [System.Collections.ArrayList]$newContent
    )
    
    try {
        # Prepare separators
        $separator = "=" * 80

        # Initialize arrays
        $sections = [System.Collections.ArrayList]@()
        $currentSection = [System.Collections.ArrayList]@()
        
        # Read existing logs if file exists
        if (Test-Path $logFile) {
            $existingLogs = Get-Content $logFile -Encoding UTF8 -ErrorAction Stop
            $inSection = $false
            
            foreach ($line in $existingLogs) {
                # Skip header
                if ($line -eq $messages.LogHeader -or $line -match "^-+$") {
                    continue
                }

                if ($line -eq $separator) {
                    if ($currentSection.Count -gt 0) {
                        $sections.Add($currentSection.Clone()) | Out-Null
                        $currentSection = [System.Collections.ArrayList]@()
                    }
                    $inSection = $true
                    continue
                }

                if ($inSection -and -not [string]::IsNullOrWhiteSpace($line)) {
                    $currentSection.Add($line) | Out-Null
                }
            }

            # Add the last section if it exists and not empty
            if ($currentSection.Count -gt 0) {
                $sections.Add($currentSection.Clone()) | Out-Null
            }
        }

        # Add new content as a new section
        $newSection = [System.Collections.ArrayList]@()
        foreach ($line in $newContent) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $newSection.Add($line) | Out-Null
            }
        }
        if ($newSection.Count -gt 0) {
            $sections.Add($newSection) | Out-Null
        }

        # Keep only the last 10 sections
        while ($sections.Count -gt 10) {
            $sections.RemoveAt(0)
        }

        # Build final content
        $finalContent = [System.Collections.ArrayList]@()
        
        # Add header
        $finalContent.Add($messages.LogHeader) | Out-Null
        $finalContent.Add("-" * 80) | Out-Null
        $finalContent.Add("") | Out-Null

        # Add sections with separators
        for ($i = 0; $i -lt $sections.Count; $i++) {
            $finalContent.Add($separator) | Out-Null
            $finalContent.Add("") | Out-Null
            foreach ($line in $sections[$i]) {
                $finalContent.Add($line) | Out-Null
            }
            $finalContent.Add("") | Out-Null
        }

        # Write to file
        $finalContent | Out-File -FilePath $logFile -Encoding UTF8 -Force
        return $true
    }
    catch {
        Write-Error "Failed to update log history: $($_.Exception.Message)"
        return $false
    }
}

# 设置日志文件路径
$logFile = Join-Path $PSScriptRoot "log.txt"
$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Function to detect CPU architecture and features
function Get-ProcessorInfo {
    try {
        $processor = Get-WmiObject -Class Win32_Processor
        $processorCount = (Get-WmiObject -Class Win32_ComputerSystem).NumberOfLogicalProcessors
        
        # Check if it's Intel or AMD
        $isIntel = $processor.Manufacturer -like "*Intel*"
        $isAMD = $processor.Manufacturer -like "*AMD*"
        
        # Check if it's a hybrid architecture (has E-cores)
        # Known Intel processors with hybrid architecture
        $hybridModels = @(
            "12th Gen", "13th Gen", "14th Gen",  # Common names
            "Core i*-12", "Core i*-13", "Core i*-14",  # Desktop naming
            "Alder Lake", "Raptor Lake"  # Architecture names
        )
        $hasECores = $false
        if ($isIntel) {
            $hasECores = $hybridModels | Where-Object { $processor.Name -like "*$_*" }
        }
        
        return @{
            ProcessorCount = $processorCount
            IsIntel = $isIntel
            IsAMD = $isAMD
            HasECores = [bool]$hasECores
        }
    }
    catch {
        Write-Error "Failed to get processor information: $($_.Exception.Message)"
        return $null
    }
}

# Function to calculate optimal affinity mask based on CPU architecture
function Get-OptimalAffinityMask {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$cpuInfo,
        [Parameter(Mandatory=$true)]
        [int]$processIndex
    )
    
    try {
        if ($cpuInfo.HasECores) {
            # For Intel with E-cores, use the last core (E-core) for both processes
            $lastCore = $cpuInfo.ProcessorCount - 1
            return [Math]::Pow(2, $lastCore)
        } else {
            # For AMD or Intel without E-cores, use the second to last core for both processes
            # Avoid first and last core for better system responsiveness
            $targetCore = $cpuInfo.ProcessorCount - 2
            return [Math]::Pow(2, $targetCore)
        }
    }
    catch {
        Write-Error "Failed to calculate affinity mask: $($_.Exception.Message)"
        return 0
    }
}

# Function to get friendly architecture name
function Get-FriendlyArchitectureName {
    param (
        [Parameter(Mandatory=$true)]
        [int]$architectureCode
    )
    
    switch ($architectureCode) {
        0 { return "x86 (32-bit)" }
        1 { return "MIPS" }
        2 { return "Alpha" }
        3 { return "PowerPC" }
        5 { return "ARM" }
        6 { return "ia64 (Itanium)" }
        9 { return "x64 (64-bit)" }
        12 { return "ARM64" }
        default { return "Unknown ($architectureCode)" }
    }
}

# Get CPU information
$cpuInfo = Get-ProcessorInfo
if ($null -eq $cpuInfo) {
    Write-Error "Failed to get CPU information"
    exit 1
}

# 初始化日志内容数组
$logContent = [System.Collections.ArrayList]@()

# 记录脚本启动和配置信息
$null = $logContent.Add("[$date] $($messages.ScriptStart)")
$null = $logContent.Add("")  # Add empty line for better readability
$null = $logContent.Add("$($messages.DetectedCores): $($cpuInfo.ProcessorCount)")
$null = $logContent.Add("Processor: $($processor.Name)")
$null = $logContent.Add("Architecture: $friendlyArchitecture")

# Add CPU architecture information to log
$cpuType = if ($cpuInfo.IsIntel) { 
    if ($cpuInfo.HasECores) { 
        "Intel (Hybrid Architecture - P-cores & E-cores)" 
    } else { 
        "Intel (Traditional - Uniform cores)" 
    }
} elseif ($cpuInfo.IsAMD) { 
    "AMD (Uniform cores)" 
} else { 
    "Unknown Architecture" 
}
$null = $logContent.Add("CPU Type: $cpuType")
$null = $logContent.Add("")  # Add empty line for better readability

# 定义进程配置
$processConfigs = @(
    @{
        Name = "SGuard64.exe"
        ProcessIndex = 0
    },
    @{
        Name = "SGuardSvc64.exe"
        ProcessIndex = 1
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
            $affinityMask = Get-OptimalAffinityMask -cpuInfo $cpuInfo -processIndex $config.ProcessIndex
            $process.ProcessorAffinity = [IntPtr]::new($affinityMask)
            $selectedCore = [Math]::Log($affinityMask, 2)
            $null = $logContent.Add("  [$($messages.Success)] $($messages.SetAffinityCore) $selectedCore")
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
    $updateSuccess = Update-LogHistory -logFile $logFile -newContent $logContent
    if (-not $updateSuccess) {
        Write-Error "Failed to update log history"
        exit 1
    }
}
catch {
    Write-Error "Failed to write log file: $($_.Exception.Message)"
    exit 1
}

# 返回执行状态
exit ([int](!$success))