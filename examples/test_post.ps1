# test presley POST

. ..\presley.ps1

get '/person' {
  # get all persons
  $content = gc .\people.tmp

  $content.trim().split(' ') -join ','
}

post '/person' {
  # pretend to upload a person
  $name = $params["name"]

  " $name" >> .\people.tmp

  "{`"msg`":`"$name added, body= $_body`"}"
}

run