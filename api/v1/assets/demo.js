(function(global) {
  
  var ProgressBar = function(statusTextEl, progressBarEl) {
    var self = {};
    self.append = function(html) {
      statusTextEl.prepend(html);
    };
    self.html = function(html) {
      statusTextEl.html(html);
    };
    self.setProgress = function(val) {
      progressBarEl.css('width', val+'%');
    };
    self.setError = function(/*html or string*/err) {
      self.html($('<div class="error">Oops, something went wrong: </div>').append(err));
    };
    return self;
  };

  var FileUploader = function(form, file_field, post_url) {
    var progressBar = ProgressBar($('#progress .text'), $('#progress .bar')),
        fileUploader = new $.fn.FileUploader(form);

    this.doUpload = function() {
      var uploader,
          resolved = false,
          deferred = $.Deferred();

      progressBar.html("Initializing");
      progressBar.setProgress(1);

      uploader = $.fn.TiramisuUploader(fileUploader, file_field[0], post_url);
      uploader.progress(function(progress) {
          progressBar.setProgress(progress.percent);
          progressBar.html(progress.status);
          var res = progress.image || progress.result;
          if (res) {
            deferred.resolve(res);
            resolved = true;
          }
        })
        .then(function() {
          if (!resolved) {
            return progressBar.setError('Unknown error.');
          }
        })
        .fail(function(progress_error) {
          progressBar.setError(progress_error.message);
          deferred.reject()
        });
      return deferred.promise();
    };
  };

  global.FileUploader = FileUploader;
}(this));