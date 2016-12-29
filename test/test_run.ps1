#=================================================
# Run test
# - start this in another PowerShell session
#=================================================

$requests_to_test = @{
  "/" = "hello world"
  "/404" = "404 not found"
  "/hi?name=dave" = "hello dave"
  "/hi/mick" = "hello mick"
  "/hello/jack/age/123" = "hello jack, you are 123"
}

function get_response($url) {
  $result = @{}
  try {
    $R = invoke-webrequest -uri $url

    $_code = $R.StatusCode
    $_headers = $R.headers
    $_body = [system.text.encoding]::utf8.getstring($R.content)

    $result = @{ code = $_code; headers = $_headers; body = $_body }
  }
  catch {
    write-host $_.exception.message -f red
  }
  $result
}

function _assert_equal($expect, $actual, $message = "") {
  if ($actual -ne $expect) {
    write-host "Assertion Failed. Expect: $expect, Actual: $actual. $message" -f red
    write-host
  }
  else {
    write-host "passed" -f green
    write-host
  }
}

$requests_to_test.keys | % {
  write-host "==> testing $_" -f cyan

  try {
    $res = get_response("http://localhost:9999" + $_)
    _assert_equal -expect $requests_to_test[$_] -actual $res["body"]
  }
  catch {
    write-host $_.exception.message -f red
    write-host
  }
}

write-host "done."