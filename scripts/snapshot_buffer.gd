class_name SnapshotBuffer
extends RefCounted

# remote state is shown this far in the past, so there are usually two snapshots to blend between
var delay := 0.1
# how far past the newest snapshot the motion is continued when packets are late
var max_extrapolation := 0.2

class Snapshot:
	var time: float
	var position: Vector3
	var yaw: float
	var pitch: float

	func _init(p_time: float, p_position: Vector3, p_yaw: float, p_pitch: float) -> void:
		time = p_time
		position = p_position
		yaw = p_yaw
		pitch = p_pitch

var _snapshots: Array[Snapshot] = []
# local time minus sender time, the clocks of the peers are unrelated
var _clock_offset := 0.0

# time is the sender's clock in seconds
func push(time: float, position: Vector3, yaw: float, pitch: float) -> void:
	# unreliable packets can arrive out of order
	if not _snapshots.is_empty() and time <= _snapshots.back().time:
		return

	var offset := _now() - time
	# average out the network jitter
	_clock_offset = offset if _snapshots.is_empty() else lerpf(_clock_offset, offset, 0.05)
	_snapshots.append(Snapshot.new(time, position, yaw, pitch))

# returns the interpolated state at the delayed render time, or null without snapshots
func sample() -> Snapshot:
	if _snapshots.is_empty():
		return null

	var render_time := _now() - _clock_offset - delay
	while _snapshots.size() > 2 and _snapshots[1].time <= render_time:
		_snapshots.pop_front()

	if _snapshots.size() == 1:
		return _snapshots[0]

	var from := _snapshots[0]
	var to := _snapshots[1]
	var span := to.time - from.time
	var weight := clampf((render_time - from.time) / span, 0.0, 1.0 + max_extrapolation / span)
	return Snapshot.new(
		render_time,
		from.position.lerp(to.position, weight),
		lerp_angle(from.yaw, to.yaw, weight),
		lerpf(from.pitch, to.pitch, weight))

func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
