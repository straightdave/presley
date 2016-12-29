# test psinatra POST

. ..\psinatra.ps1

get '/person' {
  # get all persons
  $content = gc .\people.tmp

  $content.trim().split(' ') -join ','
}

post '/person' {
  # pretend to upload a person
  $name = $_params["name"]

  " $name" >> .\people.tmp

  "{`"msg`":`"$name added, body= $_body`"}"
}

run