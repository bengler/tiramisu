
(function(global) {
  /**
   * A file uploader widget. This is the glue between the form and the file uploader
   * @param form
   * @param fileField
   * @param postUrl
   */
  var ImageUploader = function(form, fileField, postUrl) {
    var uploader = $.fn.TiramisuUploader(form),
        stages = { // Progress normalization. Since each step reports progress from 0 - 100, the overall progress  
          uploading: function(percent) { return percent/100*60; },
          received: function() { return 60; },
          transferring: function(percent) { return 60+(percent/100*30); },
          completed: function() { return 90; },
          transcoding: function(percent) { return 90+(percent/100*10); },          
          failed: function() { return 100; },
          timeout: function() { return 100; }
        },
        pollForImage = function(url, timeout) {
          var deferred = $.Deferred(),
              loader = new Image(),
              retries = 0,
              timer,
              check = function() {
                deferred.notify({status: 'transcoding', percent: 100/20*retries});
                loader.src=url+"?retry="+retries++; // Opera will cache it even if it fails
                $(loader).one('load', function() {
                  deferred.notify({status: 'transcoding', percent: 100});
                  deferred.resolve(loader.src);
                });
                $(loader).one('error', function() {
                  // manually continue polling
                  timer = setTimeout(check, 1000);
                });
              };
          check();
          // after 20 seconds of unsuccessful polling, reject it
          setTimeout(function() {
             clearTimeout(timer);
             deferred.reject({percent: 100, status:"timeout"});
           }, 20*1000);
          return deferred.promise();
        };

    // Will read contents of file_field and upload it while notifying the returned 
    // promise with progress events along the way
    this.doUpload = function() {
      var upload,
          transcode,
          deferred = $.Deferred();

      console.log(fileField)
      upload = uploader.upload(fileField[0], postUrl);
      upload.progress(function(progress) {
          progress.percent = stages[progress.status](progress.percent); // normalize progress
          deferred.notify(progress);
        })
        .then(function(metadata) {
          transcode = pollForImage(metadata.versions[0].url);
          transcode.then(function(url) {
            deferred.resolve(metadata);
          });
          transcode.progress(function(progress) {
            progress.percent = stages[progress.status](progress.percent);
            deferred.notify(progress);
          });
          transcode.fail(function() {
            deferred.reject.apply(deferred, arguments);
          });
        })
        .fail(function(error) {
          deferred.reject(error); // forward errors
        });
      return deferred.promise();
    };
  };

  /**
   * A super simple progressbar
   */
  var ProgressBar = function(statusTextEl, progressBarEl) {
    var self = {};
    self.prepend = function(html) {
      statusTextEl.prepend($("<li></li>").append(html));
    };
    self.html = function(html) {
      statusTextEl.html(html);
    };
    self.setProgress = function(val) {
      progressBarEl.css('width', val+'%');
    };
    self.setError = function(/*html or string*/err) {
      self.prepend($('<span class="error">Error: </span>').append(err));
    };
    return self;
  };
  
  /**
   * Initialize it
   */
  $(function () {
    var form = $("form#upload_image"),
        fileField = form.find('input[type=file]'),
        uploadButton = form.find('button.upload'),
        resultElement = form.find('.result'),

        uid = 'image:tiramisu.test.image',
        endpoint = '/api/tiramisu/v1/images',

        progressBar = ProgressBar(form.find('.progressbar .text'), form.find('.progressbar .indicator')),
        uploader = new ImageUploader(form, fileField, endpoint+"/"+uid),
        uploading;

    
    uploadButton.bind('click', function() {
      resultElement.html("");
      uploading = uploader.doUpload();
      uploading.progress(function(progress) {
        progressBar.setProgress(progress.percent);
        progressBar.prepend(progress.percent+"% "+progress.status);
      });
      uploading.then(function(metadata) {
        progressBar.prepend('<img src="'+metadata.versions[0].url+'">');
        progressBar.prepend($("<code></code>").append(JSON.stringify(metadata)));
      });
      uploading.fail(function(error) {
        progressBar.setError(error.message || 'unknown error');
      });
    });
  });
  
}(this));