# pSinatra (temp name)

pSinatra is a [DSL](https://en.wikipedia.org/wiki/Domain-specific_language) for
quickly creating web applications in PowerShell with minimal effort on Windows:

```powershell
# myapp.ps1
. .\psinatra.ps1

get '/' {
  'Hello world!'
}

run
```

And run with:

```powershell
PS> .\myapp.ps1
```

View at: [http://localhost:9999](http://localhost:9999)

> You may get it very soon that this pSinatra is inspired by ruby's Sinatra framework. Yes, it is!
When I was working on a C# backend project I needed a simple tool to create simple HTTP web services.
I sufferred a lot creating ASP.NET MVC projects, doing so much boilerplate stuff. At that moment I missed Sinatra sooo much.
So this idea came out to me and I began to work on it.   
'pSinatra' is temporary. Naming is a good job to do, I leave it to do later.

## Table of Contents

* [pSinatra](#psinatra)
    * [Table of Contents](#table-of-contents)
    * [Routes](#routes)
    * [Return Values](#return-values)
    * [Views / Templates](#views--templates)
        * [Literal Templates](#literal-templates)
        * [Available Template Languages](#available-template-languages)
            * [EPS Templates](#eps-templates)
        * [Accessing Variables in Templates](#accessing-variables-in-templates)
    * [Further Reading](#further-reading)

## Routes

In pSinatra, a route is an HTTP method paired with a URL-matching pattern.
Each route is associated with a block (implemented so far):

```powershell
get '/' {
  .. show something ..
}

post '/' {
  .. create something ..
}

delete '/' {
  .. annihilate something ..
}
```

Routes are matched in the order they are defined. The first route that
matches the request is invoked.

Route patterns may include named parameters, accessible via the
`$_params` hash:

```powershell
get '/hello/:name' {
  # matches "GET /hello/foo" and "GET /hello/bar"
  # $_params['name'] is 'foo' or 'bar'
  "Hello $($_params['name'])!"
}
```

You can also access named parameters via block parameters:

```powershell
get '/hello/:name' {
  param($arg)
  
  # matches "GET /hello/foo" and "GET /hello/bar"
  # $arg['name'] is 'foo' or 'bar'
  "Hello $($arg['name'])!"
}
```

Routes may also utilize query parameters:

```powershell
get '/posts' {
  # matches "GET /posts?title=foo&author=bar"
  $title  = $_params['title']
  $author = $_params['author']
  # uses title and author variables; query is optional to the /posts route
}
```

> `$_params` hash contains more things than query parameters or path variables:
arguments in POST request body (as web form parameters).   
Also, pre-defined variable `$_body` contains content in POST body. 

## Return Values

The return value of a route block determines at least the response body passed
on to the HTTP client.   

Most commonly, this is a string, as in the above examples. But other values are
also accepted. You can return any object that would either be converted to a string.

Further more, you can return a hashtable with 'headers (hashtable)', 'code (Int)'
and 'body (string)'.

> In PowerShell, the value of the last statement in a block would be the 'return' value
of that block.

## Views / Templates

Each template language is exposed via its own rendering method. These
methods simply return a string:

```powershell
get '/' {
  eps 'index'
}
```

This renders `template/index.eps`.

Instead of a template name, you can also just pass in the template content
directly:

```powershell
get '/' {
  $code = "<%= $(Get-Date).ToString('s') %>"
  eps $code
}
```

> This may be not implemented yet.

### Available Template Languages

So far only EPS adapter is implemented. You should install EPS before using this way rendering:

```powershell
PS> Install-Module EPS
```

#### EPS Templates

<table>
  <tr>
    <td>Dependency</td>
    <td>
      <a href="https://straightdave.github.io/eps/" title="eps">EPS</a>
    </td>
  </tr>
  <tr>
    <td>File Extensions</td>
    <td><tt>.eps</tt>
  </tr>
  <tr>
    <td>Example</td>
    <td><tt>eps 'index'</tt></td>
  </tr>
</table>

### Accessing Variables in Templates

Templates are **NOT** evaluated within the same context as route handlers. Instance
variables set in route handlers should passed to templates:

```powershell
get '/:id' {
  $foo = $_params['id']
  eps 'products' @{ id = $foo }
}
```

### Setting Body, Status Code and Headers

Very similar to Sinatra, other than only returning a string as response body, 
you can return a hashtable which contains headers, status code and body text:

```powershell
get '/foo' {
  $response = @{}
  $response["code"] = 233
  $response["headers"] = @{ myheader = "bar"; h33 = "2333333"}
  $response["body"] = "wahahaha hahaha"

  $response
}
```

Or simply:

```powershell
get '/bar' {
  @{ 
    headers = @{'ContentType' = 'application/json'}
    body    = "{`"msg`":`"a msg`"}"
  }
}
```

### Contribute
Anything is welcomed.

Author: eyaswoo@gmail.com
