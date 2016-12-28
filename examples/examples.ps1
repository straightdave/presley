# load psinatra
. ..\psinatra.ps1

# define routers (and actions)
get '/hello' {
  # $_param is pre-defined query parameter hashtable per request
  $name = $_param["name"]

  # $_req is pre-defined HttpListenerRequest object per request
  $path = $_req.Url.absolutepath

  # the last item is a string
  "Hello $name at $path!"
}

get '/hi' {
  $response = @{}
  $response["code"] = 233
  $response["headers"] = @{ myheader = "wahahaa"; h33 = "2333333"}
  $response["body"] = "wahahaha hahaha"

  # the last item is a hashtable
  $response
}

get '/getjson' {
  $response = @{}
  $response["headers"] = @{ "ContentType" = "application/json" }
  $response["body"] = "{`"message`":`"i am json`"}"

  $response
}

# variables in path
get '/hi/:name' {
  $name = $_param["name"] # get the variable in path from $_param

  "Hello $name!"
}

get '/hello/:name' {
  param($name)   # get the variable in path this way

  "Hello $name!"
}

# run the application
run