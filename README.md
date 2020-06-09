# URL Shortener Back End

## Installing and running server

##### 0. Prerequisites
The setups steps expect the following software installed in the system

- Git
- Ruby 2.7.0
- [Bundler](https://bundler.io/)

##### 1. Check out the repository
```bash
git clone git@github.com:kircm/url_shortener_back_end.git
```

##### 2. Running the tests
```ruby
bundle exec rails test
```

##### 3. Start the Rails server
```ruby
bundle exec rails server
```

## Using the API 

The server will run in development mode at the URL http://localhost:3000

The API follows the REST style and accepts three types of HTTP methods:

  - `GET` - retrieve an existing shortened URL and get a redirect to the corresponding longer URL
  - `POST` - create a shortened URL from a longer URL - optionally indicate a custom slug
  - `DELETE` - delete/expire an existing shortened URL

The API makes use of HTTP status codes on any HTTP response

  - `200` - request processed successfully
  - `302` - request processed successfully - being redirected to the longer URL
  - `404` - request processed successfully but record not found in DB
  - `422` - request processed unsuccessfully due to the nature of the data passed in
  - `500` - application error raised when processing request

## API specs

#### Creating a shortened URL from a longer URL
Request example: `POST http://localhost:3000/shortened_urls`
- HTTP Header `Content-Type: application/json`
- Body: 
    ```json
    {
      "url":"http://www.example.com"
    }
    ```
  The `url` attribute in the request body JSON structure specifies the longer URL to be shortened by the service 


Response example: 
- HTTP Header `Content-Type: application/json`
- Body:
    ```json
    {
      "short_url": "http://localhost:3000/shortened_urls/6lm57"
    }
    ```
  The `short_url` attribute in the response body JSON structure specifies the shortened URL created by the service
    

#### Creating a shortened URL from a longer URL Specifying a custom slug
Request example: `POST http://localhost:3000/shortened_urls`
- HTTP Header `Content-Type: application/json`
- Body: 
    ```json
    {
      "url":"http://www.example.com",
      "custom_slug":"yrslx"
    }
    ```

Response example: 
- HTTP Header `Content-Type: application/json`
- Body:
    ```json
    {
      "short_url": "http://localhost:3000/shortened_urls/yrslx"
    }
    ```
  
Potential error response:
- HTTP Status `422`
- Body
    ```json
    {
      "message": "Slug already taken."
    }
    ```
  The service enforces the consistency of the data by making slugs unique across the system 
  
  
#### Using a shortened URL to be redirected to its longer URL
Request example: `GET http://localhost:3000/shortened_urls/yrslx`

Response example: 
- HTTP Status `302`
- Redirected to the longer URL found in the system

Potential error response:
- HTTP Status `404`
  The requested shortened URL doesn't exist in the system or it's marked as expired 

  
#### Setting an existing shortened URL to expired
Request example: `DELETE http://localhost:3000/shortened_urls/yrslx`

Response example: 
- HTTP Status `200`

Potential error response:
- HTTP Status `404`
  The requested shortened URL doesn't exist in the system or it's marked as expired 


## Development decisions

### Dependency with `shortener` Gem
[shortener](https://github.com/jpmcgrath/shortener) provides very convenient functionality when processing URLs:
  - flexible [configuration](https://github.com/jpmcgrath/shortener#configuration-) (charset for slug, size of slug, etc.)
  - normalization of URLs so that "http://www.example.com" is treated the same as "http://www.example.com/" 
  (with `/` at the end) and applying other URL normalization rules 
  - handling of shortened URL parameters: a longer URL may contain parameters, which are stored in the shortened URL
  - merging of URL parameters: if a shortened URL contains parameters and it is requested while adding additional 
  parameters to it, the two sets of parameters are [merged](https://github.com/jpmcgrath/shortener#url-parameters-)

The dependency with `shortener` brings an already established Rails model `Shortener::ShortenedUrl` that we make use of.
It also brings a `Shortener::ShortenedUrlsController` which we override completely in our application.   

### REST Style
Valuing simplicity, we decided the HTTP `Status codes` would be the one and only way for the client to interpret what's 
the outcome of its request after being processed by the server. This means the API can return several error codes, 
almost all of them indicating some business logic situation (record not found, slug already taken) but also 
the `500` system/application error.

### JSON
Whenever there is the need to accept or return a data structure a JSON structure is placed in the `Body` of the 
HTTP `POST` or the HTTP Response. We do not set any status in the JSON structure, those are taken care of by 
the HTTP statuses.  
  
### Data consistency
We made the decision to return an error when the client requests the creation of a shortened URL using a custom slug
that already exists in the system. That's to enforce consistency. However, if the existing slug corresponds to the 
same longer URL that's being requested to be shortened, we reuse that existing record. 

There may be duplicates in the longer URLs that the system keeps. When requesting the creation of a longer URL with
no custom slug, the system checks for the existence of the longer URL and returns the existing shortened URL without
creating a new one. However, if the client specifies a custom slug for a longer URL that already exists in the 
system, a new record is created linked to the custom slug requested by the client. 

Having made that decision, along with the record expiration feature, it is possible that a client that did create a 
shortened URL with a dynamic slug, later "deleting" it, and later "re-creating" it again, gets assigned a previously 
existing custom slug linked to the same longer URL (a different client had created its own customized
version of the same longer URL). 

### Record expiration
Based on the loose definition of "deletion" in the requirements we followed the philosophy of how the model is coded in 
the [shortener](https://github.com/jpmcgrath/shortener) GEM. We make use of a `datetime` DB column `expires_at`. 
From the point of view of the client, an expired record is effectively deleted. The difference is that if a previously
expired shortened URL is re-created, that record is "un-expired" and its previously generated slug is returned.

This allows the system to keep track of "deletion" activity. It also leaves the door open for allowing the client to 
specify expiration date on the creation of a shortened URL in future enhancements. 

### Extension model class
The app controller interacts with the
[Shortener::ShortenedUrl](https://github.com/jpmcgrath/shortener/blob/develop/app/models/shortener/shortened_url.rb)
model. It also interacts with functionality that we provide in our class called
[ShortenedUrlExt](https://github.com/kircm/url_shortener_back_end/blob/master/app/models/shortened_url_ext.rb). 
That class contains purely-functional methods to abstract the controller from operations that are model-related and that 
we coded "on top" of the `Shortener::ShortenedUrl` model. We didn't extend the `Shortener::ShortenedUrl` class, as 
we didn't want to impact the Rails `ActiveRecord` functionality. Instead we just provide those "functions" in 
its own separate namespace. 