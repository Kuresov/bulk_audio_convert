 defmodule BulkAudioConvert do
  @doc """
  Converts all files with declared valid extensions to .mp3's using ffmpeg.
  Pass --dry to show generated commands without executing them (dry run).
  """

  @valid_ext [".ogg",".opus"]

  def main(args) do
    {opts, _, _} = args |> parse_args
    convert(get_files, opts[:dry])
  end

  def parse_args(args) do
    OptionParser.parse(args)
  end

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
      true ->
        IO.puts("Commands to be run:\n")
        elem(commands, 1)
        |> Enum.map( fn(cmd_arr) -> IO.puts("#{Enum.join(cmd_arr, " ")}") end )
      _ ->
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
    cmds
    |> Enum.with_index
    |> Enum.each( fn({cmd, i}) -> spawn_link(__MODULE__, :run_cmd, [cmd, i, self()]) end )
  end

  @doc "Run an arbitrary system command. Requires a command array and parent PID."
  def run_cmd(cmd, index_id, parent_pid) do
    status = System.cmd(hd(cmd), tl(cmd))

    case status do
      {_, 0} -> send(parent_pid, {:ok, "#{index_id} Exited successfully." })
      _ -> send(parent_pid, {:ok, "#{index_id} Exited with error: #{status}" })
    end
  end
end
