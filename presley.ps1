#=====================================================
# presley.ps1 
# (http://github.com/straightdave/presley)
#=====================================================
$routes          = @{}
$router_patterns = @{}

function get([string]$pattern, [scriptblock]$block) {
  $routes["GET $pattern"] = $block
}

function post([string]$pattern, [scriptblock]$block) {
  $routes["POST $pattern"] = $block
}

function put([string]$pattern, [scriptblock]$block) {
  $routes["PUT $pattern"] = $block
}

function delete([string]$pattern, [scriptblock]$block) {
  $routes["DELETE $pattern"] = $block
}

function run([string]$bind = "localhost", [int]$port = 9999) {
  [console]::TreatControlCAsInput = $true

  if (-not [system.net.httplistener]::IsSupported) {
    Write-Host "System.Net.HttpListener is not supported" -f red
    exit
  }

  # parse routes
  $routes.keys | % {
    $p = $_ -replace ":(\w+)", "(?<$+>\w+)"
    $router_patterns["^$p$"] = $routes[$_]
  }

  # start listener:
  $address = "http://$($bind):$($port)"
  try {
    $server = new-object -type system.net.httplistener
    $server.prefixes.add("$address/")
    $server.start()
    Write-Host "Presley is started at $address" -f cyan
  }
  catch {
    Write-Host "cannot start listening at $address" -f red
    exit
  }
 
  # packaging listener and request processing function
  # as input data of callback blocks per request
  $state = @{}
  $state['server']           = $server
  $state['_process_request'] = Get-ChildItem function:\ | ? { $_.name -eq '_process_request' }

  while($server.IsListening) {
    if ([console]::KeyAvailable) {
      $key = [system.console]::readkey($false)
      if (($key.modifiers -band [consolemodifiers]"control") `
          -and ($key.key -eq "C")) {  
        Write-Host "Presley is leaving the stage..." -f yellow
        $server.stop()
        break
      }
    }

    # non-blocking listening
    $result = $server.beginGetContext((_create_async_callback {
      param($ar)
      $data            = $ar.asyncState
      $server          = [system.net.httplistener]($data['server'])
      $context         = $server.endGetContext($ar)
      $process_request = [System.Management.Automation.FunctionInfo]($data['_process_request'])
      $process_request.ScriptBlock.Invoke($context)
    }), $state)
    [void]$result.AsyncWaitHandle.WaitOne(500)   
  }

  $server.close()
  "Presley stopped his performance. [Applaud]"
  exit
}

function eps($template_name, $bindings = @{}) {
  # default rendering using eps:
  # https://github.com/straightdave/eps
  # run 'install-module EPS' first to install EPS

  $template_folder = "$(Get-Location)\views"
  $template_file   = "$template_folder\$template_name.eps"

  # not using safe mode due to a bug of EPS
  # it should use safe-mode here
  Invoke-EpsTemplate -Path $template_file -binding $bindings
}

function halt($responseHash = @{}) {
  # stop processing at once and respond
  $err =  _my_err 'halt', $responseHash
  throw $err
}

function redirect_to($relative_uri) {
  halt @{
    code = 302;
    headers = @{ Location = $relative_uri }
  }
}

#--------------------------
# internal functions
#--------------------------
function _process_request($context) {
  $_process_start_time = Get-Date
  $_path_variables     = @{}

  # notice: 
  # variables in this block are accessable by users
  $request  = $context.Request
  $response = $context.Response
  $params   = $request.QueryString

  try {
    $_key_to_match = $request.HttpMethod + " " + $request.Url.AbsolutePath
    $_block        = _process_routes $router_patterns $_key_to_match

    if ($_block -ne $null) {
      if ($_block -isnot "scriptblock") {
        _log_err -context $context -message "no block defined for $_key_to_match"
        throw "no block defined for $_key_to_match"
      }

      if ($request.HttpMethod -eq "POST" -or `
          $request.HttpMethod -eq "PUT") {
        $_reader = New-Object -type system.io.streamreader `
                   $request.inputstream
        $body = $_reader.readtoend()
        $body.split('&') | % {
          $_splits = $_.split('=')
          $params[$($_splits[0])] = (?? $_splits[1] "")
        }
        $_reader.Close()
      }

      $block_result = $_block.Invoke($_path_variables)[-1]
      if ($block_result -is "hashtable") {
        _write -res $response -hash $block_result
      }
      else {
        _write_text -res $response -text $block_result
      }
    }
    else {
      _write -res $response `
             -hash @{
               code = 404; 
               body = "<h1>Presley doesn't know this ditty</h1><p>$_key_to_match</p>"
              }
    }
    _log_once -context $context -start_time $_process_start_time
  }
  catch {
    $err = $_.exception.GetBaseException()

    if ($err -is "PresleyException") {
      if ($err.Name -eq 'halt') {
        _write -response $response -hash $err.Data
        return
      }
    }

    # not halted
    _log_err -context $context -message $_.exception.message
    _write -res $response `
          -hash @{
            code = 500;
            headers = @{'Content-Type' = 'text/html'};
            body = "<h2>Something went run</h2><p>$($_.exception)</p>"
            }
  }
}

function _process_routes($router_patterns, $key_to_match) {
  $router_patterns.keys | % {
    $this_pattern = $_
    if ($key_to_match -match $this_pattern) {
      $matches.keys | % {
        if ($_ -is "string") {
          $_path_variables[$_] = $matches[$_]
          $_path_variables.Keys | % {
            $params[$_] = $_path_variables[$_]
          }
        }
      }
      $block = $router_patterns[$this_pattern]
      return
    }
  }
  $block
}

function _coalesce($a, $b) { if ($a -ne $null) { $a } else { $b } }
new-alias "??" _coalesce -force

function _my_err([array]$errorData) {
  if (-not ("PresleyException" -as [type])) {
    Write-Verbose "define my exception" -Verbose
    Add-Type @"
      using System;   
      public sealed class PresleyException: Exception
      {
          public string Name { get; set; }
          public new Object Data { get; set; }
      }
"@
  }
  $err = New-Object -TypeName PresleyException
  $err.Name = $errorData[0]
  $err.Data = $errorData[1]
  $err
}

function _log_once($context, $start_time) {
  $time   = Get-Date
  $dur    = $time.millisecond - $start_time.millisecond
  $ip     = $context.request.RemoteEndPoint
  $method = $context.request.HttpMethod
  $path   = $context.request.RawUrl
  $ver    = $context.request.ProtocolVersion
  $code   = $context.response.StatusCode
  Write-Verbose "$ip -- [$($time.ToString("s"))] $method $path HTTP $ver $code ($dur ms)" -Verbose
}

function _log_err($context, $message) {
  $time   = Get-Date
  $ip     = $context.request.RemoteEndPoint
  $method = $context.request.HttpMethod
  $path   = $context.request.RawUrl
  $ver    = $context.request.ProtocolVersion
  Write-Verbose "$ip -- [$($time.ToString("s"))] $method $path HTTP $ver $message" -Verbose
}

function _write($response, [hashtable]$hash = @{}) {
  $headers = ?? $hash["headers"] @{}
  $headers.keys | % {
    $response.headers.add($_, $headers[$_])
  }
  $response.StatusCode = ?? $hash["code"] 200
  $body = ?? $hash["body"] ""
  $buffer = [System.Text.Encoding]::utf8.GetBytes($body)
  $stream = $response.outputstream
  $stream.write($buffer, 0, $buffer.length)
  $stream.close()
}

function _write_text($response, $text) {
  _write -response $response -hash @{ body = $text }
}

function _flatten_dict([hashtable]$dict = @{}) {
  $sb = New-Object -type System.Text.StringBuilder
  $dict.Keys | % { [void]$sb.Append($_ + "=" + $dict[$_] + ";") }
  $sb.ToString()
}

function _create_async_callback ([scriptblock]$Callback) {
  # thanks to Oisin G. and his post:
  # http://www.nivot.org/blog/post/2009/10/09/PowerShell20AsynchronousCallbacksFromNET
  if (-not ("CallbackEventBridge" -as [type])) {
    Add-Type @"
      using System;
       
      public sealed class CallbackEventBridge
      {
          public event AsyncCallback CallbackComplete = delegate { };
          private CallbackEventBridge() {}

          private void CallbackInternal(IAsyncResult result)
          {
              CallbackComplete(result);
          }

          public AsyncCallback Callback
          {
              get { return new AsyncCallback(CallbackInternal); }
          }

          public static CallbackEventBridge Create()
          {
              return new CallbackEventBridge();
          }
      }
"@
  }
  $bridge = [callbackeventbridge]::create()
  Register-ObjectEvent -input $bridge -EventName callbackcomplete -action $callback -messagedata $args > $null
  $bridge.callback
}

#------------------------
# define built-in routes
#------------------------
get '/_routes' {
  # show all defined routes
  $sb = New-Object -type System.Text.StringBuilder
  [void]$sb.Append("<p><table>")
  $routes.Keys | % { [void]$sb.Append("<tr><td>$_</td></tr>") }
  [void]$sb.Append("</table></p>")
  $sb.ToString()
}