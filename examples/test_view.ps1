. ..\presley.ps1

get '/hello/:name' {
  $name = $params["name"]
  eps 'hello' @{ name = $name }
}

run