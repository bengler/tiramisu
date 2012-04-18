
(function(global) {

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
        uploader = $.fn.TiramisuUploader(form),
        uploading;
 
    $('#upload_btn').bind('click', function() {
      $("#result").html("");
      progressBar.html("");
      uploading = uploader.upload(file_field, endpoint+"/"+uid);
      uploading.progress(function(progress) {
        progressBar.setProgress(progress.percent);
        progressBar.prepend(progress.percent+"% "+progress.status);
      });
      uploading.then(function(metadata) {
        progressBar.prepend('<a href="'+metadata.original+'" target="_blank">Download file</a>');
        progressBar.prepend($("<code></code>").append(JSON.stringify(metadata)));
      });
      uploading.fail(function(error) {
        progressBar.setError(error.message || 'unknown error');
      });
    });
  });
  
}(this));