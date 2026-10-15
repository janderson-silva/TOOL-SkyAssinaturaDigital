param(
  [Parameter(Mandatory=$true)][string]$InputPdf,
  [Parameter(Mandatory=$true)][string]$OutputPng,
  [Parameter(Mandatory=$true)][int]$Page
)
$ErrorActionPreference = 'Stop'
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
  [Windows.Data.Pdf.PdfDocument,Windows.Data.Pdf,ContentType=WindowsRuntime] | Out-Null
  [Windows.Storage.Streams.InMemoryRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime] | Out-Null
  $script:asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
  } | Select-Object -First 1
  # PowerShell cannot always infer IAsyncAction from a WinRT __ComObject.
  # Select the exact non-generic overload instead of using its overload binder.
  $script:asActionTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and -not $_.IsGenericMethod -and
    $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.FullName -eq 'Windows.Foundation.IAsyncAction'
  } | Select-Object -First 1
  if ($null -eq $script:asTask -or $null -eq $script:asActionTask) {
    throw 'As sobrecargas WinRT necessarias nao foram encontradas no Windows PowerShell.'
  }
  function Await-Result($Operation, [Type]$Type) {
    $arguments = New-Object 'System.Object[]' 1
    $arguments[0] = $Operation
    $task = $script:asTask.MakeGenericMethod($Type).Invoke($null, $arguments)
    return $task.GetAwaiter().GetResult()
  }
  function Await-Action($Action) {
    $arguments = New-Object 'System.Object[]' 1
    $arguments[0] = $Action
    $task = $script:asActionTask.Invoke($null, $arguments)
    $task.GetAwaiter().GetResult() | Out-Null
  }
  $file = Await-Result ([Windows.Storage.StorageFile]::GetFileFromPathAsync($InputPdf)) ([Windows.Storage.StorageFile])
  $pdf = Await-Result ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument])
  $pdfPage = $pdf.GetPage([uint32]$Page)
  $stream = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
  try {
    $action = $pdfPage.RenderToStreamAsync($stream)
    Await-Action $action
    $stream.Seek(0)
    $reader = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)
    $output = [System.IO.File]::Create($OutputPng)
    try { $reader.CopyTo($output) } finally { $output.Dispose(); $reader.Dispose() }
  } finally { $pdfPage.Dispose(); $stream.Dispose() }
  exit 0
} catch {
  [System.IO.File]::WriteAllText($OutputPng + '.error', $_.Exception.ToString())
  exit 1
}
