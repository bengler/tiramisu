/**
 * A simple poller
 * Usage:
 *  var obj = [1,2,3];
 *  Poll(obj).every(200).for(4000).start().progress(function(data) {
 *      console.log("I received", data)
 *  });
 *
 *  setTimeout(function() {
 *       obj[obj.length] = 'some';
 *       obj[obj.length] = 'more';
 *  }, 1000);
 *
 * =>
 */
(function ($) {

  var Repeat = (function () {
    var times_map = {
      one:1, two:2, three:3, four:4, five:5, six:6, seven:7, eight:8, nine:9, ten:10,
      twenty:20, fifty:50, hundred:100, thousand:1000
    },

    units_map = (function () {
      var map = {};
      $.each([
        {factor:1, names:['ms', 'msec', 'msecs', 'milliseconds', 'millisecond']},
        {factor:1000, names:['s', 'secs', 'sec', 'seconds', 'second']},
        {factor:1000 * 60, names:['m', 'mins', 'min', 'minutes', 'minute']},
        {factor:1000 * 60 * 60, names:['h', 'hours', 'hour']}
      ], function (_, unit) {
        $.each(unit.names, function (_, name) {
          map[name] = unit.factor;
        });
      });
      return map;
    }()),

    with_unit_as_args = function wrapped(func) {
      return function (val, unit) {
        if (!unit) return val;
        if (unit && !units_map[unit]) throw new Error('Unknown unit "' + unit + '" must be one of [' + $.map(units_map,
            function (v, k) {
              return k.toString()
            }).join(", ") + ']');
        return func.call(func, Math.max(36, units_map[unit] * val))
      }
    };

    return function (task) {
      var opts, interval, counter = 0, started = false, self = new $.Deferred();

      opts = {
        task: task || null,
        every:-1, // will not be repeated
        times:-1, // defaults to once
        _for:-1, // ever
        until: null // ever
      };

      var chained = function (func) {
        return function chained() {
          func.apply(func, arguments);
          return self;
        }
      };

      self.task = chained(function (task) {
        opts.task = task;
      });

      self.every = chained(with_unit_as_args(function (ms) {
        opts.every = ms;
      }));

      self['lasting'] = chained(with_unit_as_args(function (ms) {
        opts._for = ms;
      }));

      self.times = chained(function (times) {
        opts.times = times;
      });

      self['as'] = chained(function (func) {
        opts.until = function() {return !func()};
      });

      self['until'] = chained(function (func) {
        opts.until = func;
      });

      self.step = chained(function () {
        if ($.isFunction(opts.until) && opts.until()) self.stop();
        else if (~opts._for && (new Date().getTime() - started) > opts._for) self.stop();
        else if (~opts.times && ++counter === opts.times) self.stop();
        else opts.task();
      });

      self.start = function () {
        if (started) throw Error("Already started");
        else if (!self.task) throw Error("Don't know any task");
        else if (!$.isFunction(self.task)) throw Error("Task is not a function");
        started = new Date().getTime();
        opts.task();
        if (~opts.every) {
          interval = setInterval(function () {
            self.step();
          }, opts.every);
        }
        return self.promise();
      };

      self['delay'] = with_unit_as_args(function (ms) {
        setTimeout(function () {
          self.start()
        }, ms);
        return self.promise();
      });

      self.shutdown = function () {
        return self.step().stop();
      };
      self.stop = chained(function () {
        clearInterval(interval);
        self.resolve();
      });

      $.each(times_map, function (key, value) {
        self[key] = {times:function () {
          self.times(value);
          return self;
        }};
      });

      // Add some grammatical convenience
      self.once = self['one'].time = self['one'].times;
      self.twice = self.two.times;
      self.now = self.start;

      return self;
    }
  })();

  var Poll = (function () {
    var range = function (obj, from, to) {
      if (typeof obj == 'string') return obj.substring(from, to);
      else if ($.isArray(obj)) {
        return obj.slice(from, to);
      }
    };

    var resolveDataArgs = function(object, property) {
      return (property && object[property]) ?
              ($.isFunction(object[property]) ?
                  function () {
                    return object[property].call(object)
                  } : function () {
                return object[property]
              }) :
              ($.isFunction(object) ? object : function () {
                return object
              });
    };

    return function () {
      var self = Repeat();
      self.data = function(object, property) {
        var getData = resolveDataArgs(object, property);
        var wrapped = (function () {
          var last_len = 0;
          return function () {
            var current_data = getData(),
                current_len = current_data.length;
            if (current_len > last_len) {
              self.notify(range(current_data, last_len, current_len));
            }
            last_len = current_len;
          }
        }());
        return self.task(wrapped);
      };
      return self;
    };
  }());

  $.fn.Poller = {
    Repeat: Repeat,
    Poll: Poll
  };
})(jQuery);