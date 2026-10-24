extends GdUnitTestSuite
## Discord IPC frames: opcode and length as little-endian u32, then the JSON payload.


func test_frame_has_header_and_json() -> void:
	var bytes := DiscordPresence.frame(DiscordPresence.OP_FRAME, {"v": 1})
	var json := JSON.stringify({"v": 1}).to_utf8_buffer()
	assert_int(bytes.decode_u32(0)).is_equal(1)
	assert_int(bytes.decode_u32(4)).is_equal(json.size())
	assert_array(Array(bytes.slice(8))).is_equal(Array(json))


func test_activity_is_a_no_op_without_discord() -> void:
	var presence: DiscordPresence = auto_free(DiscordPresence.new())
	add_child(presence)
	presence.set_activity("In camp")
	assert_object(presence._pipe).is_null()
