(function ($, Repeat) {
  /**
   * Fallback iframe uploader legacy browsers (like IE 9) not supporting the HTML5 File API (http://www.w3.org/TR/FileAPI/)
   * It mimics the progress notification
   *
   * Tested in:
   *  [x] IE 6
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
    };

    var extend = function(obj, source) {
      for (var prop in source) {
        if (source[prop] !== void 0) obj[prop] = source[prop];
      }
      return obj;
    };
    var shiftAttrs = function(elem, attrs) {
      var old = {};
      $.each(attrs, function(attr, new_value) {
        if (attr == 'enctype' && !new_value) new_value = 'application/x-www-form-urlencoded';
        old[attr] = elem.attr(attr);
        // jquery bug #
        elem.attr(attr, new_value || '');
      });
      return old;
    };

    return function(form) {
      var iframe,
          iframe_name = 'uploader_iframe_'+Math.random().toString(36).substring(2),
          self = {};

      iframe = $('<iframe id="'+iframe_name+'" name="'+iframe_name+'" style="display:none"></iframe>')
                .appendTo(form);

      self.upload = function(file_field, url) {
        var deferred = $.Deferred(),
            real_upload = self.upload,
            overridden_attrs = shiftAttrs(form, {
              target: iframe_name,
              action: url,
              enctype: 'multipart/form-data'
            });

        self.upload = function() {/* throttle */};

        $(iframe).load(function() {
          var contents = $(iframe).contents(),
              body = contents.find('body'),
              title = contents.find('title'),
              response = {
                responseText: body && body.text() || '',
                statusText: title && title.text() || '',
                readyState: 4,
                status: 200
              };

          if (response.responseText.charAt(0) == '{') {
            var json = JSON.parse(response.responseText);
            extend(response, json);
            (response.status < 200 || response.status > 299) ?
                deferred.reject(response) : deferred.resolve(response);
          }
          else {
            // its not json, assume 500 (unexpected) server error
            response.status = 500;
            response.responseText = $(iframe).contents()[0].documentElement.innerHTML;
            deferred.reject(response);
          }

          deferred.always(function() {
            form.unbind('submit', preventSubmit);
            shiftAttrs(form, overridden_attrs);
            self.upload = real_upload;
          });
        });
        form.unbind('submit', preventSubmit);
        form[0].submit();
        form.bind('submit', preventSubmit);

        // fake progress at regular intervals (it can be useful i.e. for knowing how long an upload is taking)
        // whether it is standard behaviour to send progress events when lengthComputable is false is not
        // specified by the w3c (http://www.w3.org/TR/progress-events/)
        Repeat(function() {
          deferred.notify({lengthComputable: false, loaded: 0, total: 0});
        })
          .every(200, 'ms')
          .until(function() {return deferred.isResolved()})
          .now();

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
    var superset = function(src, props) {
      var cloned = {};
      for (var i = props.length; i--;) {
        cloned[props[i]] = src[props[i]];
      }
      return cloned;
    };
    var normalizeXhr = function(xhr) {
      return superset(xhr, ['responseText', 'status', 'statusText', 'readyState'])
    };
    return function(/*ignored*/form) {
      var self = {};
      self.upload = function(file_field, url) {
        var deferred = $.Deferred();

        //if (!file_field || !file.type.match(/image.*/)) return; todo show thumbnail

        var file = file_field.files[0]; // todo: support multiple files

        var fd = new FormData();
        fd.append(file_field.name, file); // Append the file

        var xhr = new XMLHttpRequest();
        xhr.open("POST", url);

        xhr.addEventListener("load", function() {
          var e = normalizeXhr(xhr);
          (xhr.status < 200 || xhr.status > 299) ? deferred.reject(e) : deferred.resolve(e);
        }, false);
        xhr.addEventListener("error", function() {
          deferred.reject(normalizeXhr(xhr));
        }, false);
        xhr.addEventListener("abort", function() {
          deferred.reject(normalizeXhr(xhr));
        }, false);
        xhr.upload.addEventListener("progress", function (e) {
          deferred.notify(e);
        }, false);

        xhr.send(fd);
        return deferred;
      };
      return self;
    }
  }());


  var TiramisuUploader = function(/* $.fn.FileUploader*/ uploader, file_field, url, poller_url) {
    var deferred = $.Deferred(),
        poller = $.fn.SimplePoll(poller_url),
        received = false; // will be set to true when server indicates that image is received

    poller.progress(function(events) {
        $.each(events, function(i, event) {
          deferred.notify(event);
          if (event.split(";")[1] === 'received') received = true;
        });
      })
      .fail(function(res) { /* ignore? */ })
      .then(function(res) { /* ignore? */ });

    uploader.upload(file_field, url)
      .progress(function(e) {
        if (received) return; // We're using IframeUploader and waiting for server response. However, the progress
                              // tracker has reported that the file is received server side.
        if (e.lengthComputable) {
          var percent = Math.ceil((e.loaded / e.total)*100);
          deferred.notify(percent+';uploading');
        }
        else {
          // The file upload API is for some reason unable to provide file stats
          deferred.notify('-1;uploading');
        }
      })
      .fail(function(xhr) {
        deferred.reject(xhr)
      })
      .then(function(xhr) {
        deferred.resolve(xhr)
      });
    return deferred;
  };


  TiramisuUploader.generate_transaction_id = function() {
    return new Date().getTime()+Math.random().toString(36).substring(2);
  };


  // feature detection for File API
  // TODO Fix: jQuery plugins should *never* export more than one function
  $.fn.FileUploader = FormData === undefined ? IframeUploader : XhrUploader;
  $.fn.TiramisuUploader = TiramisuUploader;

  // todo:remove the following lines two lines
  $.fn.IframeUploader = IframeUploader;
  $.fn.XhrUploader = XhrUploader;
})(jQuery, window.Repeat);
