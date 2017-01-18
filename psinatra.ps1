#=====================================================
# psinatra.ps1 
# (http://github.com/straightdave/psinatra)
#=====================================================

$routers         = @{}
$router_patterns = @{}

function get($path, $block) {
  $routers["GET $path"] = $block
}

function post($path, $block) {
  $routers["POST $path"] = $block
}

function run($bind = "localhost", [int]$port = 9999, [int]$max = 50) {
  if (-not [system.net.httplistener]::IsSupported) {
    write-host "http listener is not supported" -f red
    exit
  }

  # pre-processing:
  # analyze the url matching patterns
  # routers => router_patterns
  $routers.keys | % {
    $p = $_ -replace ":(\w+)", "(?<$+>\w+)"
    $router_patterns["^$p$"] = $routers[$_]
  }

  # start listener:
  $address = "http://$($bind):$($port)"
  try {
    $server = new-object -type system.net.httplistener
    $server.prefixes.add("$address/")
    $server.start()
    write-host "Sinatra is started at $address" -f cyan
  }
  catch {
    write-host "cannot start listening at $address" -f red
    exit
  }

  [console]::TreatControlCAsInput = $true
  $pool = [RunspaceFactory]::CreateRunspacePool(1, $max)
  $pool.open()

  $waiters = $a = New-Object System.Collections.ArrayList
  
  # main loop:
  # a) observing keyboard event (ctrl-c)
  # b) printing each worker's output, if any
  while($server.IsListening) {
    if ([console]::KeyAvailable) {
      $key = [system.console]::readkey($false)
      if (($key.modifiers -band [consolemodifiers]"control") `
          -and ($key.key -eq "C")) {  
        write-host "Sinatra is leaving the stage..." -f yellow
        $server.stop()
        break
      }
    }

    # non-blocking listening
    $waiter = $server.beginGetContext((_create_callback {
      param($ar)

      $_server = [system.net.httplistener]$ar.asyncState
      $_context = $_server.endGetContext($ar)
      $_res = $_context.response
      _write_text -res $_res -text "hello world"

      write-host "delete in list..." >> c:\users\wwe\desktop\temp.txt
      $waiters.remove($ar)
    }), $server)

    if ($waiter -eq $null) {
      write-host "get waiter null" -f red
      break
    }

    if (-not $waiter.isCompleted) {
      $waiters.add($waiter)
    }

    if ($waiters.count -gt 99) {
      write-host "already 100 waiters waiting." -f yellow
      $tmp = $waiters[0]
      $tmp.asyncWaitHandle.waitOne()
      $waiters.remove($tmp)
    }
  }

  $server.close()
  "Sinatra stopped his performance. [Applaud]"
  exit
}

function _coalesce($a, $b) { if ($a -ne $null) { $a } else { $b } }
new-alias "??" _coalesce -force

function _print_all_workers_output($workers) {
  $workers | % {
    write-host $_.streams.verbose
    write-host $_.streams.error -f red
  }
}

function _do_with_request($context) {
  $start_time      = Get-Date
  $_req            = $context.Request
  $_res            = $context.Response
  $_params         = $_req.QueryString
  $_path_variables = @{}

  try {
    $key   = $_req.HttpMethod + " " + $_req.Url.AbsolutePath
    $block = _matching_router -router_patterns $router_patterns `
                              -request_to_test $key

    if ($block -ne $null) {
      if ($block -isnot "scriptblock") {
        _log_err -context $context -message "no block defined for $key"
        return
      }

      if ($_req.HttpMethod -eq "POST" -or `
          $_req.HttpMethod -eq "PUT") {
        $reader = new-object -type system.io.streamreader `
                  $_req.inputstream
        $_body = $reader.readtoend()
        $_body.split('&') | % {
          $this_kv = $_
          $splits = $this_kv.split('=')
          $_params[$($splits[0])] = (?? $splits[1] "")
        }
      }

      $block_result = $block.Invoke($_path_variables)[-1]
      if ($block_result -is "hashtable") {
        _write -res $_res -hash $block_result
      }
      else {
        _write_text -res $_res -text $block_result
      }
    }
    else {
      _write -res $_res `
             -hash @{code = 404; body = "<h1>Sinatra doesn't know this ditty</h1><h2>$key</h2>"}
    }

    _log_once -context $context -start_time $start_time
  }
  catch {
    _log_err -context $context -message $_.exception.message
  }
}

function _matching_router($router_patterns, $request_to_test) {
  $block = $null
  $router_patterns.keys | % {
    $this_p = $_
    if ($request_to_test -match $this_p) {
      $matches.keys | % {
        if ($_ -is "string") {
          $global:_params[$_]         = $matches[$_]
          $global:_path_variables[$_] = $matches[$_]
        }
      }
      $block = $router_patterns[$this_p]
      return
    }
  }
  $block
}

function _log_once($context, $start_time) {
  $dur    = (Get-Date).millisecond - $start_time.millisecond
  $ip     = $context.request.RemoteEndPoint
  $method = $context.request.HttpMethod
  $path   = $context.request.RawUrl
  $ver    = $context.request.ProtocolVersion
  $code   = $context.response.StatusCode
  write-verbose "$ip -- [$time] `"$method $path`" HTTP $ver $code ($dur ms)" -verbose
}

function _log_err($context, $message) {
  $ip     = $context.request.RemoteEndPoint
  $method = $context.request.HttpMethod
  $path   = $context.request.RawUrl
  $ver    = $context.request.ProtocolVersion
  write-verbose "$ip -- [$(get-date)] `"$method $path`" HTTP $ver $message" -verbose
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

function _create_callback ([scriptblock]$Callback) {
  # thank you Oisin G.
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


