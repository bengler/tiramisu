# Tiramisu

[![Build Status](https://semaphoreapp.com/api/v1/projects/07b8419278106d09595c3737e0b53ee5aee4d072/28252/badge.png)](https://semaphoreapp.com/projects/1574/branches/28252)

A service for managing user-originated uploads and asset-processing.

Uses _S3_ for storage, _Tootsie_ for transcoding and _ImageMagick_ for file identification.

## Getting Started

    git clone git@github.com:pebblestack/tiramisu.git tiramisu

Make sure you have ImageMagick installed via your favorite package manager. Confirm that you
are able to run `identify` on the command line.

## Config

Your configuration goes in `config/services.yml`.

    cp config/services-example.yml config/services.yml

You have one configuration for each environment.

Tiramisu uses the environment variable `RACK_ENV` to determine current environment.

    ---
    development:
      S3:
        access_key_id: <aws access key>
        secret_access_key: <aws secret>
        bucket: <your bucket name>
      tootsie: http://<url to your tootsie web-service>
    production:
      ...

## Api

Upload an image by posting multipart form-data with the asset in the field "file". E.g

    curl -F "file=@mypicture.jpg" "http://tiramisu.dev/api/tiramisu/v1/images/:uid"

The `:uid` is in the form of a partial pebbles-uid without the object id. In other words, something like this:

    `image:myclient.myapp.kittens`

`myclient.myapp.kittens` is used to scope the image by client, service, user or other criteria. It is a '.'-separated
string of labels.

If the operation succeeds a complete uid is returned with a generated object id, like this:

    `image:myclient.myapp.kittens$20120105134610-1498-bp5o`

If the image format is not supported, the action fails with 400 and the content `{"error":"format-not-supported"}`,
if processing times out it fails with the content `{"error":"timeout"}`.

This action will write progress updates to a streamed HTTP response while submitting to tootsie/uploading image to S3.
Clients may listen for changes to the response in order to provide progress feedback to the user.

If you require processing notifications from tootsie, specify the query-parameter `notification_url`.
The format of these messages is documented in [Tootsie's README](https://github.com/alexstaubo/tootsie#readme)

    curl -F "file=@mypicture.jpg" "http://tiramisu.dev/api/tiramisu/v1/images/:uid?notification_url=..."

Typical response:

```json
{"percent":0,"status":"received"}
{"percent":20,"status":"transferring"}
// ...
{"percent":75,"status":"transferring"}
{"percent":90,"status":"transferring"}
{"percent":100,"status":"completed","image": { // NOTE: formatted on mulitple lines for readability. In reality, this is a one-liner
    "id":"image:myclient.myapp.something$20120105134610-1498-bp5o",
    "baseurl":"http://yourbucketname.s3.amazonaws.com/myclient/myapp/something/20120105134610-1498-bp5o",
    "sizes":[
        {
            "width":100,
            "square":true,
            "url":"http://yourbucketname.s3.amazonaws.com/myclient/myapp/something/20120105134610-1498-bp5o/100.jpg"
        },
        // ... other sizes
        {
            "width":5000,
            "square":false,
            "url":"http://yourbucketname.s3.amazonaws.com/myclient/myapp/something/20120105134610-1498-bp5o/5000.jpg"
        }
    ],
    "original":"http://yourbucketname.s3.amazonaws.com/myclient/myapp/something/20120105134610-1498-bp5o/original.jpeg",
    "aspect":1.4988290398126465
    }
}
```

If the transaction fails, progress reports `{"progress": 100, "status":"failed", "message": "<error message>"}` and closes the connection.

NOTE: the sizes hash for an image after a successfull post request does not indicate whether the image is ready
to be displayed or not (that is, processed by tootsie and available at the S3 URL).

The client can verify that the image is present by trying to fetch the url, and checking if that request fails or not.

This is best implemented in javascript using an image object of which we listen for `load` or `error` events.
Example implementation with jQuery:

```javascript
var poll = function (url) {
  var retries = 0;
  var loader = new Image();
  var attempt = function() {
    jQuery(loader).one('load', function () {
      // image is ready
    });
    jQuery(loader).one('error', function () {
      // image is not ready continue polling
      setTimeout(attempt, 1000);
    });
    loader.src = url + "?retry=" + retries++; // Need a different url every time, cause Opera will cache it even if it fails
  };
  attempt();
};
```

## Known issues/TODO

* Tiramisu provides a TiramisuUploader jQuery plugin available at /api/tiramisu/v1/assets/tiramisu.js.
  This is not yet documented and probably deserves its own wiki page.

## Deployment

When configuring this service for production mind the following points:

* The service writes to a streamed response in order to provide progress reports to the client
  and it uses the header X-Accel-Buffering to disable buffering of output with nginx.

* Given that this is an upload service the `client_max_body_size` of nginx or corresponding
  parameter of your other servers and proxies must be set accordingly.

* Timeout is a matter of concern. The upload action of this service will not let the user
  go until the image is safely uploaded to S3 and at least a thumbnail is ready for
  display. Thus unicorn and possibly other services in the http-chain must be configured
  to allow considerable connection time. Minutes!

* Tiramisu employs Tootsie to transcode the images. A tootsie pipeline must be configured in
  services.yml
