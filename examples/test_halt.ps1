. ..\presley.ps1

get '/' {
  "hello"
}

get '/goto' {
  redirect_to '/'
}

run