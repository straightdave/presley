#============================================
# Test Entry of pSinatra project
#============================================
. ..\psinatra.ps1

get '/' {
  "hello world"
}

get '/404' {
  @{ code = 404; body = "404 not found" }
}

get '/hi' {
  $name = $_params["name"]
  "hello $name"
}

get '/hi/:name' {
  $name = $_params["name"]
  "hello $name"
}

get '/hello/:name/age/:age' {
  param($var)

  $name = $var["name"]
  $age  = $var["age"]
  "hello $name, you are $age"
}

run