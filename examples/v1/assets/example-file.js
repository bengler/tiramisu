(function(global) {
  /**
   * A file uploader widget. This is the glue between the form and the file uploader
   * @param form
   * @param file_field
   * @param post_url
   */
  var PlainFileUploader = function(form, file_field, post_url) {
    var fileUploader = new $.fn.FileUploader(form),
        stages = { // Progress normalization (since each step reports progress between 0 and 100)
          uploading: function(percent) { return percent/100*60; },
          received: function() { return 60; },
          transferring: function(percent) { return 60+(percent/100*40); },
          completed: function() { return 100; },
          failed: function() { return 100; }
        };

    // Will read contents of file_field and upload it while notifying the returned 
    // promise with progress events along the way
    this.doUpload = function() {
      var uploader, deferred = $.Deferred(), poller;

      uploader = $.fn.TiramisuUploader(fileUploader, file_field[0], post_url);
      uploader.progress(function(progress) {
          progress.percent = stages[progress.status](progress.percent); // normalize progress
          deferred.notify(progress); // simply forward it
          if (progress.file) {
            deferred.resolve(progress.file); // If progress comes with an image, that means processing is completed
          }
        })
        .then(function() {
          if (deferred.state() === 'pending') {
            // Uploader is complete but deferred still in a pending state.
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

        uid = 'file:tiramisu.test.file',
        endpoint = '/api/tiramisu/v1/files',

        progressBar = ProgressBar(form.find('.progressbar .text'), form.find('.progressbar .indicator')),
        uploader = new PlainFileUploader(form, file_field, endpoint+"/"+uid),
        uploading;
 
    $('#upload_btn').bind('click', function() {
      $("#result").html("");
      progressBar.html("");
      uploading = uploader.doUpload();
      uploading.progress(function(progress) {
        progressBar.setProgress(progress.percent);
        progressBar.prepend(progress.percent+"% "+progress.status);
      });
      uploading.then(function(file) {
        progressBar.prepend('<a href="'+file.original+'" target="_blank">Download file</a>');
        progressBar.prepend($("<code></code>").append(JSON.stringify(file)));
      });
      uploading.fail(function(error) {
        progressBar.setError(error.message || 'unknown error');
      });
    });
  });
  
}(this));