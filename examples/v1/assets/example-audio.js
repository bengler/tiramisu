(function(global) {
  /**
   * A file uploader widget. This is the glue between the form and the file uploader
   * @param form
   * @param file_field
   * @param post_url
   */
  var AudioUploader = function(form, file_field, post_url) {
    var fileUploader = new $.fn.FileUploader(form),
        stages = { // Progress normalization. Since each step reports progress from 0 - 100, the overall progress  
          uploading: function(percent) { return percent/100*60; },
          received: function() { return 60; },
          transferring: function(percent) { return 60+(percent/100*30); },
          completed: function() { return 90; },
          transcoding: function(percent) { return 90+(percent/100*10); },          
          failed: function() { return 100; },
          timeout: function() { return 100; }
        },
        pollForTranscoded = function(url, timeout) { // somehow...
          var deferred = $.Deferred(),
              retries = 0,
              timer,
              check = function() {
                deferred.notify({status: 'transcoding', percent: 100/20*retries});
                /*loader.src=url+"?retry="+retries++; // Opera will cache it even if it fails
                $(loader).one('load', function() {
                  deferred.notify({status: 'transcoding', percent: 100});
                  deferred.resolve(loader.src);
                });
                $(loader).one('error', function() {
                  // manually continue polling
                  timer = setTimeout(check, 1000);
                });*/
              };
          check();
          // after 20 seconds of unsuccessful polling, reject it
          setTimeout(function() {
             clearTimeout(timer);
             deferred.reject("timeout");
           }, 20*1000);
          return deferred.promise();
        };

    // Will read contents of file_field and upload it while notifying the returned 
    // promise with progress events along the way
    this.doUpload = function() {
      var uploader, deferred = $.Deferred(), poller;

      uploader = $.fn.TiramisuUploader(fileUploader, file_field[0], post_url);
      uploader.progress(function(progress) {
          progress.percent = stages[progress.status](progress.percent); // normalize progress
          deferred.notify(progress); // simply forward it
          
          if (progress.audio_clip) {
            poller = pollForTranscoded(progress.audio_clips.original);
            poller.progress(function(progress) {
              progress.percent = stages[progress.status](progress.percent); // normalize progress              
              deferred.notify(progress);
            });
            poller.then(function() {
              deferred.resolve(progress.audio_clips); // If progress comes with an image, that means processing is completed              
            });
            poller.fail(function(arg) {
              deferred.reject(arg);
            });
          }
        })
        .then(function() {
          if (!poller) {
            // Uploader is complete but poller is not started.
            // Assume something went wrong and reject
            deferred.reject({percent: 100, status:"failed"});
          }
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
    var form = $("form#upload"),
        file_field = $("#file"),

        uid = 'document:tiramisu.test.audio_clips',
        endpoint = '/api/tiramisu/v1/audio_clips',

        progressBar = ProgressBar(form.find('.progressbar .text'), form.find('.progressbar .indicator')),
        uploader = new AudioUploader(form, file_field, endpoint+"/"+uid),
        uploading;
 
    $('#upload_btn').bind('click', function() {
      $("#result").html("");
      progressBar.html("");
      uploading = uploader.doUpload();
      uploading.progress(function(progress) {
        if (progress.audio_clips) {
          progressBar.prepend($("<code></code>").append(JSON.stringify(progress.audio_clips)));
        }
        progressBar.setProgress(progress.percent);
        progressBar.prepend(progress.percent+"% "+progress.status);
      });
      uploading.then(function(audio_clip) {
        progressBar.prepend('<img src="'+audio_clips.original+'">');
        progressBar.prepend($("<code></code>").append(JSON.stringify(audio_clips)));
      });
      uploading.fail(function(error) {
        progressBar.setError(error.message || 'unknown error');
      });
    });
  });
  
}(this));