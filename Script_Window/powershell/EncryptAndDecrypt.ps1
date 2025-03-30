# 设置控制台代码页为 UTF-8
chcp 65001 > $null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 导入必要的命名空间
Add-Type -AssemblyName System.Security

function Encrypt-String
{
    param (
        [string]$plainText,
        [byte[]]$key,
        [byte[]]$iv
    )

    # 创建 AES 算法实例
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV = $iv

    # 创建加密器
    $encryptor = $aes.CreateEncryptor($aes.Key, $aes.IV)

    # 转换字符串为字节数组
    $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($plainText)

    # 使用内存流和加密转换器加密数据
    $msEncrypt = New-Object System.IO.MemoryStream
    $csEncrypt = New-Object System.Security.Cryptography.CryptoStream($msEncrypt, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
    $csEncrypt.Write($plainBytes, 0, $plainBytes.Length)
    $csEncrypt.FlushFinalBlock()

    # 获取加密后的字节数组并转换为 Base64 字符串
    $cipherBytes = $msEncrypt.ToArray()
    [System.Convert]::ToBase64String($cipherBytes)
}

function Decrypt-String
{
    param (
        [string]$cipherText,
        [byte[]]$key,
        [byte[]]$iv
    )

    # 创建 AES 算法实例
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV = $iv

    # 创建解密器
    $decryptor = $aes.CreateDecryptor($aes.Key, $aes.IV)

    # 将 Base64 编码的字符串转换回字节数组
    $cipherBytes = [System.Convert]::FromBase64String($cipherText)

    # 使用内存流和解密转换器解密数据
    $msDecrypt = New-Object System.IO.MemoryStream
    $csDecrypt = New-Object System.Security.Cryptography.CryptoStream($msDecrypt, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
    $csDecrypt.Write($cipherBytes, 0, $cipherBytes.Length)
    $csDecrypt.FlushFinalBlock()

    # 将解密后的字节数组转换回字符串
    $decryptedBytes = $msDecrypt.ToArray()
    [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
}

############################ 使用示例：
# 生成密钥和初始化向量 (IV)
$key = [System.Text.Encoding]::UTF8.GetBytes("jracf88vCEBeRNdtNr3SnPkCrzepBcjt") # 必须是16, 24, 或32字节长以匹配AES-128, AES-192, 或 AES-256
$iv = [System.Text.Encoding]::UTF8.GetBytes("aDKHDA2uAdwdetWz") # 必须是16字节长

# 测试加密和解密  AES 加密和解密
$originalText = "Zjzx123!"
$cipherText = Encrypt-String -plainText $originalText -key $key -iv $iv
Write-Output "Encrypted: $cipherText"

$decryptedText = Decrypt-String -cipherText $cipherText -key $key -iv $iv
Write-Output "Decrypted: $decryptedText"
