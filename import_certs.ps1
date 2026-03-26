$javaHome = "C:\Program Files\Android\Android Studio\jbr"
$keytool = "$javaHome\bin\keytool.exe"
$cacerts = "$javaHome\lib\security\cacerts"

$certFiles = Get-ChildItem "C:\temp\netfree_*.cer"
$i = 0
foreach ($certFile in $certFiles) {
    $alias = "netfree_$i"
    & $keytool -delete -alias $alias -keystore $cacerts -storepass changeit 2>$null
    $result = & $keytool -import -trustcacerts -alias $alias -file $certFile.FullName -keystore $cacerts -storepass changeit -noprompt 2>&1
    Write-Host "[$i] $($result | Select-Object -Last 1)"
    $i++
}
Write-Host "Done adding $i certs"
Read-Host "Press Enter to close"
