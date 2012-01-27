(function ($, Repeat) {
  /**
   * TODO: BN cleanup & refactor!
   *
   * Fallback iframe uploader legacy browsers (like IE 9) not supporting the HTML5 File API (http://www.w3.org/TR/FileAPI/)
   * It mimics the progress notification
   *
   * Tested in:
   *  [ ] IE 6
   *  [ ] IE 7
   *  [ ] IE 8
   *  [ ] IE 9
   *
   *  It **should** also work in other browsers not supporting the file api
   *
   * Known issues:
   *  - No support for XDR
   *  - No support for multiple files
   *  - It posts all form data through an iframe, not only content of file fields
   *  - Expects that the upload URL returns something that resembles an XHR object ({status: xxx, responseText: '(...)'} etc.
   *    Anything apart from JSON is treated as a general 500 error with response body as responseText
   *  - IE8 has some ways of simulating progress event that could be considered supporting
   */
	var IframeUploader = (function () {

    var preventSubmit = function(e) {
        e.preventDefault();
        return false;
      },
      shiftAttrs = function(elem, attrs) {
        var old = {};
        $.each(attrs, function(attr, new_value) {
          if (attr == 'enctype' && !new_value) new_value = 'application/x-www-form-urlencoded';
          old[attr] = elem.attr(attr);
          // jquery bug #
          elem.attr(attr, new_value || '');
        });
        return old;
      },
      getFrameBody = function (iframe) {
        var contents = $(iframe).contents(),
            body = contents.find('body');
        return body;
      };

    return function(form) {
      var iframe,
          iframe_name = 'uploader_iframe_'+Math.random().toString(36).substring(2),
          self = {}

      iframe = $('<iframe id="'+iframe_name+'" name="'+iframe_name+'" style="display:none"></iframe>')
                .appendTo(form);

      self.upload = function(file_field, url) {
        var deferred = $.Deferred(),
            real_upload = self.upload,
            overridden_attrs = shiftAttrs(form, {
              target: iframe_name,
              action: url,
              enctype: 'multipart/form-data'
            }),
            initial_response_received = false;

        getFrameBody(iframe).empty();

        self.upload = function() {/* throttle */};

        var poll = $.fn.Poll();
        poll.data(function () {
            var content = $.trim(getFrameBody(iframe).text());
            return content ? content.split("\n") : content;
          })
          .every(200, 'ms').start();

        poll.progress(function(chunks){
          $.each(chunks, function(i, chunk) {
            initial_response_received = true;
            if (chunk.charAt(0) == '{') {
              deferred.notify(JSON.parse(chunk));
            }
            else {
              // its not json, assume the server threw an unexpected server error
              deferred.reject(chunk);
            }
          })
        });

        Repeat((function() {
          var fake_percent = 0;
          return function() {
            fake_percent += ((100-fake_percent)/100);
            deferred.notify({percent: fake_percent, approximate: true, status: 'uploading'});
          };
         }))
         .every(100, 'ms')
         .until(function() {
            return initial_response_received;
          })
         .now();

        $(iframe).one('load', function() {
          poll.step().then(function() {
            deferred.resolve();
          }).resolve();
        });

        deferred.always(function() {
          form.unbind('submit', preventSubmit);
          shiftAttrs(form, overridden_attrs);
          self.upload = real_upload;
        });
        form.unbind('submit', preventSubmit);
        form[0].submit();
        form.bind('submit', preventSubmit);

        return deferred;
      };
      return self;
    }
	}());

  /**
   * Tested in:
   *  [x] FF 8
   *  [x] Chrome 16
   *  [x] Opera 11.6
   *  [x] Safari 5.1
   *
   *  Known issues/todo:
   *  - Implement multiple file support
   */
  var XhrUploader = (function() {

    return function(/*ignored*/form) {
      var self = {};
      self.upload = function(file_field, url) {
        var deferred = $.Deferred(),
            poll = new $.fn.Poll();

        //if (!file_field || !file.type.match(/image.*/)) return; todo show thumbnail

        var file = file_field.files[0]; // todo: support multiple files

        var fd = new FormData();
        fd.append(file_field.name, file); // Append the file

        var xhr = new XMLHttpRequest();
        xhr.open("POST", url);

        xhr.addEventListener("error", function() {
          deferred.reject();
        }, false);

        xhr.addEventListener("abort", function() {
          deferred.reject();
        }, false);

        xhr.upload.addEventListener("progress", function (e) {
           // Set to -1 if the file upload API for some reason is unable to provide file stats
          var percent = e.lengthComputable ? Math.ceil((e.loaded / e.total)*100) : -1;
          deferred.notify({percent: percent, status:'uploading'});
        }, false);

        poll.then(function() {
          deferred[(xhr.status < 200 || xhr.status > 299) ? 'reject' : 'resolve']();
        });

        // ----------
        // Read streamed response from the tiramisu upload action and treat as progress events
        xhr.onreadystatechange = function () {
          if (xhr.readyState == 3) {
            poll.data(function() {
              return $.trim(xhr.responseText).split("\n");
            }).every(200, 'ms').start();
            xhr.onreadystatechange = function() {
              if (xhr.readyState == 4) {
                poll.step().stop();
              }
            }
          }
        };
        poll.progress(function(chunks){
          $.each(chunks, function(i, chunk) {
            if (chunk.charAt(0) == '{') {
              deferred.notify(JSON.parse(chunk));
            }
            else {
              // its not json, assume the server threw an unexpected server error
              deferred.reject(chunk);
            }
          })
        });
        // ----------

        xhr.send(fd);
        return deferred;
      };
      return self;
    }
  }());

  var TiramisuUploader = function(/* $.fn.FileUploader*/ uploader, file_field, url) {
    return uploader.upload(file_field, url);
  };

  // feature detection for File API
  // TODO Fix: jQuery plugins should *never* export more than one function
  $.fn.FileUploader = FormData === undefined ? IframeUploader : XhrUploader;
  $.fn.TiramisuUploader = TiramisuUploader;

  // todo:remove the following lines two lines
  $.fn.IframeUploader = IframeUploader;
  $.fn.XhrUploader = XhrUploader;
})(jQuery, window.Repeat);
