defmodule FireSense do
  @moduledoc """
  Wi-Fi fire detection experiments on a Raspberry Pi 5.

  Use these from the IEx prompt (`ssh nerves.local`):

      FireSense.start()            # begin a new recording session
      FireSense.mark("walk")       # note an event: walk, door, kettle, flame on...
      FireSense.status()           # current session, row count and latest reading
      FireSense.stop()             # finish and close the files
      FireSense.sessions()         # list recorded sessions

  Copy data to your computer with:

      scp -r nerves.local:/data/sessions .
  """

  alias FireSense.Recorder

  defdelegate start(name \\ nil), to: Recorder, as: :start_session
  defdelegate stop(), to: Recorder, as: :stop_session
  defdelegate mark(note), to: Recorder
  defdelegate status(), to: Recorder

  @doc "List recorded session folders."
  def sessions do
    dir = Application.get_env(:fire_sense, :data_dir, "/data/sessions")

    case File.ls(dir) do
      {:ok, names} -> Enum.sort(names)
      {:error, _} -> []
    end
  end
end
