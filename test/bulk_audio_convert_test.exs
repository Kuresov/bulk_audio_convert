defmodule BulkAudioConvertTest do
  use ExUnit.Case
  doctest BulkAudioConvert

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "#convert_cmd/1" do
    test_filename = "test.ogg"
    valid_command = BulkAudioConvert.convert_cmd("test.ogg")

    expected_command = [
      "ffmpeg",
      "-i",
      "#{test_filename}",
      "-acodec",
      "libmp3lame",
      "-write_xing",
      "0",
      "test.mp3"
    ]

    assert valid_command == expected_command
  end
end
