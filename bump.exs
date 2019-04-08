defmodule Bump do
  def run do
    patterns = [
      {"mix.exs", ~r/@version\s"(?<version>\d+.\d+.\d+)"/, &mix_builder/1},
      {"README.md", ~r/{:red_mutex,\s*"~>\s*(?<version>\d+.\d+.\d+)"}/, &readme_builder/1}
    ]

    type = type()

    {files, new_version} = patterns
    |> Enum.map(fn {filename, pattern, new_version_builder} ->
      file_content = File.read!(filename)

      new_version = pattern
      |> Regex.named_captures(file_content)
      |> Map.fetch!("version")
      |> Version.parse!()
      |> Map.update!(type, &(&1 + 1))

      new_content = Regex.replace(pattern, file_content, new_version_builder.(new_version))

      File.write!(filename, new_content)

      {filename, new_version}
    end)
    |> Enum.reduce({[], nil}, fn {filename, new_version}, {files, _} ->
      {[filename | files], to_string(new_version)}
    end)

    Enum.each(files, fn file ->
      System.cmd("git", ["add", file], into: IO.stream(:stdio, :line))
    end)

    System.cmd("git", ["commit", "-m", "v#{new_version}"], into: IO.stream(:stdio, :line))
    System.cmd("git", ["tag", "-a", "v#{new_version}", "-m", "v#{new_version}"], into: IO.stream(:stdio, :line))
  end

  defp type do
    System.argv()
    |> parse_args()
  end

  defp parse_args(["major"]), do: :major
  defp parse_args(["minor"]), do: :minor
  defp parse_args(["patch"]), do: :patch
  defp parse_args(args), do: raise ArgumentError, "Invalid bump type: `#{Enum.join(args, " ")}`"

  defp readme_builder(new_version), do: ~s({:red_mutex, "~> #{new_version}"})
  defp mix_builder(new_version), do: ~s(@version "#{new_version}")
end

Bump.run()
