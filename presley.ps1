#==========================================================
# presley.ps1 - a web framework for Windows in PowerShell
# http://github.com/straightdave/presley
#==========================================================

#--------------------------
# stuff exposed to users
#--------------------------
function get([string]$pattern, [scriptblock]$block) {
  $routes["GET $pattern"] = $block
  #$routes["HEAD $pattern"] = $block
}

function post([string]$pattern, [scriptblock]$block) {
  $routes["POST $pattern"] = $block
}

function put([string]$pattern, [scriptblock]$block) {
  $routes["PUT $pattern"] = $block
}

function patch([string]$pattern, [scriptblock]$block) {
  $routes["PATCH $pattern"] = $block
}

function delete([string]$pattern, [scriptblock]$block) {
  $routes["DELETE $pattern"] = $block
}

function set([string]$configKey, [string]$configValue) {
  $configs[$configKey] = $configValue
}

function run([string]$bind = "localhost", [int]$port = 9999, [hashtable]$config = @{}) {
  [console]::TreatControlCAsInput = $true

  if (-not [system.net.httplistener]::IsSupported) {
    Write-Host "System.Net.HttpListener is not supported" -f red
    return
  }

  # merge config
  $config.Keys | % { $configs[$_] = $config[$_] }

  # parse routes
  $routes.keys | % {
    $p = $_ -replace ":(\w+)", "(?<$+>\w+)"
    $router_patterns["^$p$"] = $routes[$_]
  }

  # start listener
  $address = "http://$bind`:$port"
  try {
    $server = new-object -type system.net.httplistener
    $server.prefixes.add("$address/")
    $server.start()
    Write-Host "Presley is started at $address" -f cyan
  }
  catch {
    Write-Host "cannot start listening at $address" -f red
    return
  }

  # tricks: using $state to package listener and request-process function
  # as the input data of callback blocks per request
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
  "Presley finished his performance. [Applaud]"
}

function eps($template_name, $bindings = @{}) {
  # using EPS (https://github.com/straightdave/eps) to render response
  # run 'install-module EPS' at first to install EPS

  $template_location  = ?? $configs["template_folder"] "views"
  $template_extension = ?? $configs["template_ext"] "eps"
  $template_folder    = "$(Get-Location)\$template_location"
  $template_file      = "$template_folder\$template_name.$template_extension"
  Invoke-EpsTemplate -Path $template_file -safe -binding $bindings
}

function json($object, [int]$code = 200) {
  @{
    headers = @{ 'Content-Type' = 'application/json' };
    code    = $code;
    body    = ConvertTo-Json $object
  }
}

function html($text, [int]$code = 200) {
  @{
    headers = @{ 'Content-Type' = 'text/html' };
    code    = $code;
    body    = $text
  }
}

function halt($responseHash = @{}) {
  $err =  _my_err 'halt', $responseHash
  throw $err
}

function redirect_to($relative_uri, $code = 302) {
  halt @{
    code = $code;
    headers = @{ Location = $relative_uri }
  }
}

#------------------------------------------------------
# internal stuff:
# currently I just WISH with crossed fingers that
# users won't use stuff here
#------------------------------------------------------
$routes          = @{}
$router_patterns = @{}
$configs         = @{
  "template_folder"  = "views";
  "template_ext"     = "eps";
  "default_encoding" = "utf8";
  "env"              = "dev";
}

function _process_request($httpContext) {
  $_process_start_time = Get-Date
  $_path_variables     = @{}

  # heads-up:
  # variables in this function are accessable in user-defined route blocks.
  # some built-in variables defined here:
  $context  = $httpContext
  $request  = $context.Request
  $response = $context.Response
  $params   = $request.QueryString

  try {
    $_key_to_match = $request.HttpMethod + " " + $request.Url.AbsolutePath
    $_block        = _find_block_for_route $router_patterns $_key_to_match

    if ($_block -ne $null) {
      if ($request.HttpMethod -eq "POST" -or `
          $request.HttpMethod -eq "PUT"  -or `
          $request.HttpMethod -eq "PATCH") {
        $_reader = New-Object -type system.io.streamreader `
                   $request.inputstream
        $body = $_reader.readtoend()
        $_reader.Close()

        if ($request.ContentType -eq "application/x-www-form-urlencoded") {
          $body.split('&') | % {
            $_splits = $_.split('=')
            $params[$($_splits[0])] = ?? $_splits[1] ""
          }
        }
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

    _log_err -context $context -message $_.exception.message
    _write -res $response `
          -hash @{
            code = 500;
            headers = @{'Content-Type' = 'text/html'};
            body = "<h2>Something went run</h2><p>$($_.exception)</p>"
            }
  }
}

function _find_block_for_route($patternHash, $key) {
  $patternHash.keys | % {
    $p = $_
    if ($key -match $p) {
      $matches.keys | % {
        if ($_ -is "string") {
          $_path_variables[$_] = $matches[$_]
          $_path_variables.Keys | % {
            $params[$_] = $_path_variables[$_]
          }
        }
      }
      $block = $router_patterns[$p]
      return
    }
  }
  $block
}

function _coalesce($a, $b) { if ($a -ne $null) { $a } else { $b } }
New-Alias "??" _coalesce -force

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

function _write($response, [hashtable]$hash = @{}, [boolean]$hasBody = $true) {
  $headers = ?? $hash["headers"] @{}
  $headers.keys | % { $response.headers.add($_, $headers[$_]) }
  $response.StatusCode = ?? $hash["code"] 200
  $body = ?? $hash["body"] ""
  $_encoding = ?? $configs["default_encoding"] "utf8"
  $buffer = [System.Text.Encoding]::($_encoding).GetBytes($body)

  #$response.ContentLength = $buffer.length  # WRONG
  
  if ($hasBody) {
    $stream = $response.outputstream
    $stream.write($buffer, 0, $buffer.length)
    $stream.close()
  }
}

function _write_text($response, $text) {
  _write -response $response -hash @{ body = $text }
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
  $sb = New-Object -type System.Text.StringBuilder
  [void]$sb.Append("<p><table>")
  $routes.Keys | % { [void]$sb.Append("<tr><td>$_</td></tr>") }
  [void]$sb.Append("</table></p>")
  $sb.ToString()
}