
(function(global) {
  /**
   * A file uploader widget. This is the glue between the form and the file uploader
   * @param form
   * @param file_field
   * @param post_url
   */
  var AudioUploader = function(form, file_field, post_url) {
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
        pollForTranscoded = function(uid, timeout) { // somehow...
          var deferred = $.Deferred(),
              retries = 0,
              timer,
              check = function() {
                deferred.notify({status: 'transcoding', percent: 100/20*retries});
                $.get("/api/tiramisu/v1/audio_files/"+uid+"/status").then(function(file) {
                  $.each(file.versions, function(i, version) {
                    if (version.ready) {
                      deferred.resolve(file);
                    }
                  });
                  if (deferred.state() === 'pending') {
                    retries++;
                    timer = setTimeout(check, 1000);  
                  }
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

      upload = uploader.upload(file_field[0], post_url);
      upload.progress(function(progress) {
          progress.percent = stages[progress.status](progress.percent); // normalize progress
          deferred.notify(progress);
        })
        .then(function(metadata) {
          transcode = pollForTranscoded(metadata.uid);
          transcode.then(function(metadata) {
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
    var form = $("form#upload"),
        file_field = $("#file"),

        uid = 'audio:tiramisu.test.audio_files',
        endpoint = '/api/tiramisu/v1/audio_files',

        progressBar = ProgressBar(form.find('.progressbar .text'), form.find('.progressbar .indicator')),
        uploader = new AudioUploader(form, file_field, endpoint+"/"+uid),
        uploading;
 
    $('#upload_btn').bind('click', function() {
      $("#result").html("");
      progressBar.html("");
      uploading = uploader.doUpload();
      uploading.progress(function(progress) {
        var metadata = progress.metadata;
        if (metadata) {
          progressBar.prepend($("<code></code>").append(JSON.stringify(metadata)));
          progressBar.prepend('<a href="'+metadata.original+'" target="_blank">Download original</a>');
          $.each(metadata.versions, function(i, version) {
            progressBar.prepend('<a href="'+version.url+'" target="_blank">Download '+version.format+' (may not be ready yet)</a>');          
          });
        }
        progressBar.setProgress(progress.percent);
        progressBar.prepend(progress.percent+"% "+progress.status);
      });
      uploading.then(function(metadata) {
        $.each(metadata.versions, function(i, version) {
          if (version.ready) {
            progressBar.prepend('Ready: <a href="'+version.url+'" target="_blank">Download '+version.format+'</a>');
          }          
        });
      });
      uploading.fail(function(error) {
        progressBar.setError(error.message || 'unknown error');
      });
    });
  });
  
}(this));