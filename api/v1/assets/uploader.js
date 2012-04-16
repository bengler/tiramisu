(function ($) {
  /**
   *
   * Fallback iframe uploader legacy browsers (like IE 9) not supporting the HTML5 File API (http://www.w3.org/TR/FileAPI/)
   * It mimics the progress notification during upload
   *
   * Tested in:
   *  [ ] IE 6 (who cares?)
   *  [x] IE 7
   *  [x] IE 8
   *  [x] IE 9
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
          if (attr === 'enctype' && !new_value) {
            new_value = 'application/x-www-form-urlencoded';
          }
          old[attr] = elem.attr(attr);
          // jquery bug #
          elem.attr(attr, new_value || '');
        });
        return old;
      },
      ltrim = function (str, chr) {
        var i = -1;
        if (!chr) chr = ' ';
        while (str.charAt(++i) === chr);
        return str.substring(i, str.length);
      },
      getFrameBody = function (iframe) {
        var doc = iframe.contentWindow || iframe.contentDocument;
        doc = doc && (doc.document || doc);
        return ltrim(doc.body.innerText);
      };

    return function(form) {
      var
          iframe_name = 'uploader_iframe_'+Math.random().toString(36).substring(2),
          self = {},
          iframe = $('<iframe id="'+iframe_name+'" name="'+iframe_name+'" style="display:none"></iframe>').appendTo(form);

      self.upload = function(file_field, url) {
        var deferred = $.Deferred(),
            real_upload = self.upload,
            overridden_attrs = shiftAttrs(form, {
              target: iframe_name,
              action: url,
              enctype: 'multipart/form-data'
            }),
            initial_response_received = false;

        $(iframe).contents().find('body').empty();

        self.upload = function() {/* throttle */};

        var poll = $.fn.Poller.Poll();
        poll.data(function () {
            var content = getFrameBody(iframe[0]);
            var chunks = content.split("\n");
            return chunks.slice(0,chunks.length-1);
          })
          .every(200, 'ms').start();

        poll.progress(function(chunks){
          $.each(chunks, function(i, chunk) {
            initial_response_received = true;
            var json;
            try {
              json = JSON.parse(chunk);
            }
            catch (e) { // if its not json, assume the server raised an unexpected error
              json = { "percent": 100, "status":"failed", "message": chunk };
            }
            if (json.status === 'failed') {
              deferred.reject(json);
            }
            else {
              deferred.notify(json);
              if (json.status === 'completed') {
                poll.stop();
                deferred.resolve();
              }
            }
          });
        });

        $.fn.Poller.Repeat((function() {
          var fake_percent = 0;
          return function() {
            fake_percent += ((100-fake_percent)/100);
            deferred.notify({percent: fake_percent, approximate: true, status: 'uploading'});
          };
         }()))
         .every(100, 'ms')
         .until(function() {
            return initial_response_received;
          })
         .now();

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
    };
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
            poll = new $.fn.Poller.Poll();

        //if (!file_field || !file.type.match(/image.*/)) return; todo show thumbnail

        var file = file_field.files[0]; // todo: support multiple files

        var fd = new FormData();
        fd.append(file_field.name, file);

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
          if (xhr.readyState === 3) {
            poll.data(function () {
              var chunks = xhr.responseText.split("\n");
              return chunks.slice(0,chunks.length-1);
            })
            .every(200, 'ms').start();
            xhr.onreadystatechange = function() {
              if (xhr.readyState === 4) {
                poll.step().stop();
              }
            };
          }
        };
        poll.progress(function(chunks){
          $.each(chunks, function(i, chunk) {
            var json;
            try {
              json = JSON.parse(chunk);
            }
            catch (e) { // if its not json, assume the server raised an unexpected error
              json = { "percent": 100, "status":"failed", "message": chunk };
            }
            if (json.status === 'failed') {
              deferred.reject(json);
            }
            else {
              deferred.notify(json);
            }
          });
        });
        // ----------

        xhr.send(fd);
        return deferred;
      };
      return self;
    };
  }());

  // Feature detect whether the browser supports the File API
  var FileUploader = window.FormData === undefined ? IframeUploader : XhrUploader;

  $.fn.TiramisuUploader = function(form) {
    var fileUploader = new FileUploader(form);
    return {
      upload: function(file_field, url) {
        var deferred = $.Deferred(),
            upload = fileUploader.upload.apply(fileUploader, arguments);
        
        upload.fail(function() { deferred.reject.apply(deferred, arguments); });
        upload.progress(function(progress) {
          deferred.notify.apply(deferred, arguments);
          if (progress.status === 'completed') {
            deferred.resolve(progress.metadata);
          }
          if (progress.status === 'failed') {
            deferred.reject(progress);
          }
        });
        upload.then(function() {
          if (deferred.state() === 'pending') {
            // Connection is closed, but deferred has not been resolved
            // Assume something went wrong and reject
            deferred.reject({status:'failed', message: ''});
          } 
        });
        return deferred.promise();
      }
    };
  };
  
})(jQuery);
