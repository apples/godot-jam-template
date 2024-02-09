@tool
class_name Future
extends RefCounted

## Usage:
## ```
## await Future.all_signals([page_death.finished, book_anim.animation_finished]).done
## ```

signal done(results: Array)

var _results: Array = []

var _remaining: int

static func all_signals(signals: Array[Signal]) -> Future:
	var f := Future.new()
	f._results.resize(signals.size())
	f._remaining = signals.size()
	for i: int in signals.size():
		var s := signals[i]
		var c := func _all_signals_call():
			f._results[i] = await s
			assert(f._remaining > 0)
			f._remaining -= 1
			if f._remaining <= 0:
				f.done.emit(f._results)
		c.call()
	return f
