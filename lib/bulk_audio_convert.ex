defmodule BulkAudioConvert do
  @doc """
  Converts all files with declared valid extensions to .mp3's using ffmpeg.
  Pass true to show generated commands without executing them.
  """

  @valid_ext [".ogg",".opus"]

  def start(dry_run), do: convert(get_files, dry_run)

  def get_files, do: File.ls

  def validate_filename(filename) do
    File.dir?(filename) || !Enum.any?(@valid_ext, &(String.contains?(filename, &1)))
  end

  def convert(file_list, dry_run) do
    clean_file_list = fn(files) ->
      Enum.reject(files, &(validate_filename(&1)))
    end

    commands = 
      case file_list do
        {:ok, files} -> {:ok, Enum.map(clean_file_list.(files), &(convert_cmd(&1)))}
        {:error, reason} -> raise reason
      end

    case dry_run do
      true -> commands
      false ->
        run_cmds(commands)
        {_, cmd_arr} = commands
        listen(Enum.count(cmd_arr))
    end
  end

  def listen(n) do
    cond do
      n > 0 ->
        receive do
          {:ok, msg} ->
            IO.puts "Received: #{msg}"
            listen(n - 1)
          {:error, msg} ->
            raise "Error: #{msg}"
        end
      n <= 0 ->
        IO.puts "\n\n Finished"
    end
  end

  def convert_cmd(filename) do
    new_name = hd(String.split(filename, ~r/\./)) <> ".mp3"
    [
      "ffmpeg",
      "-i",
      "#{filename}",
      "-acodec",
      "libmp3lame",
      "-write_xing",
      "0",
      "#{new_name}"
    ]
  end

  def run_cmds({:error, reason}), do: raise reason
  def run_cmds({:ok, cmds}) do
    IO.puts "Starting commands..."
    Enum.map( cmds,
      fn(cmd) -> spawn_link(__MODULE__, :run_cmd, [cmd, self()]) end
    )
  end

  @doc "Run an arbitrary system command. Requires a command array and parent PID."
  def run_cmd(cmd, parent_pid) do
    status = System.cmd(hd(cmd), tl(cmd))

    case status do
      {_, 0} -> send(parent_pid, {:ok, "#{self()} Exited successfully." })
      _ -> send(parent_pid, {:ok, "#{self()} Exited with error: #{status}" })
    end
  end
end
