package bperf
import "core:math"
import "core:sort"
import "core:time"

Stats :: struct {
	frames_per_second:     f64,
	average_frame_time:    time.Duration,
	median_frame_time:     time.Duration,
	low_1pct_frame_time:   time.Duration,
	low_0_1pct_frame_time: time.Duration,
}

Tracker :: struct {
	frame_times: [dynamic]time.Duration,
	last_frame:  time.Tick,
	last_clear:  time.Tick,
}

make_tracker :: proc(allocator := context.allocator) -> (data: Tracker) {
	data.frame_times = make([dynamic]time.Duration, 0, 2048, allocator)
	data.last_frame = time.tick_now()
	data.last_clear = time.tick_now()
	return
}

destroy_tracker :: proc(data: ^Tracker) {
	if data.frame_times != nil {
		delete(data.frame_times)
	}

	data^ = {}
}

start_frame :: proc(data: ^Tracker) {
	assert(data != nil)
	append(&data.frame_times, time.tick_lap_time(&data.last_frame))
}

reset :: proc(data: ^Tracker) {
	clear(&data.frame_times)
	data.last_clear = time.tick_now()
}

collect_stats :: proc(data: ^Tracker) -> (Stats, bool) {
	stats, ok := get_stats(data)
	if !ok {
		return {}, false
	}

	reset(data)
	return stats, true
}

collect_stats_after :: proc(data: ^Tracker, interval_secs: f64) -> (Stats, bool) {
	time_since_clear := time.duration_seconds(time.tick_since(data.last_clear))
	if time_since_clear >= interval_secs || interval_secs == 0.0 {
		return collect_stats(data)
	}

	return {}, false
}

get_stats :: proc(data: ^Tracker) -> (Stats, bool) {
	if len(data.frame_times) == 0 {
		return {}, false
	}

	sort.quick_sort(data.frame_times[:])

	fps := f64(len(data.frame_times)) / time.duration_seconds(time.tick_since(data.last_clear))
	avg := average(data.frame_times[:])
	median := median(data.frame_times[:])
	low_1pct := average_tail(data.frame_times[:], 1.0)
	low_0_1pct := average_tail(data.frame_times[:], 0.1)

	return {
			frames_per_second = fps,
			average_frame_time = avg,
			median_frame_time = median,
			low_1pct_frame_time = low_1pct,
			low_0_1pct_frame_time = low_0_1pct,
		},
		true
}

@(private = "file")
average :: proc(frame_times: []time.Duration) -> time.Duration {
	if len(frame_times) == 0 {
		return 0.0
	}

	sum := time.Duration(0)
	for frame_time in frame_times {
		sum += frame_time
	}
	return sum / time.Duration(len(frame_times))
}

@(private = "file")
median :: proc(sorted_frame_times: []time.Duration) -> time.Duration {
	if len(sorted_frame_times) == 0 {
		return 0.0
	}

	median: time.Duration
	if len(sorted_frame_times) % 2 == 0 {
		first_middle := len(sorted_frame_times) / 2
		second_middle := len(sorted_frame_times) / 2 - 1
		median = (sorted_frame_times[first_middle] + sorted_frame_times[second_middle]) / 2
	} else {
		median = sorted_frame_times[len(sorted_frame_times) / 2]
	}

	return median
}

@(private = "file")
average_tail :: proc(sorted_frame_times: []time.Duration, percentile: f64) -> time.Duration {
	assert(percentile > 0.0 && percentile <= 100.0)

	if len(sorted_frame_times) == 0 {
		return 0
	}

	count := int(math.ceil(f64(len(sorted_frame_times)) * (percentile / 100.0)))
	start := len(sorted_frame_times) - count

	sum := time.Duration(0)
	for frame_time in sorted_frame_times[start:] {
		sum += frame_time
	}

	return sum / time.Duration(count)
}
