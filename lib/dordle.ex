defmodule Dordle do
  @moduledoc """
  Implementation of the word game Wordle. Six guesses to find the target
  5-letter word. After each guess the guesses so far are output, each
  letter color-coded green if it's in the word and in the correct spot; yellow
  if it's in the word but in the wrong spot, and no color if it's not in the
  word at all.
  """

  # TODO: Could rot13 the word in state if we really wanted to make it not
  # directly in get_state/0 (which I'm keep a def and not defp for debugging
  # and such)

  @word_file "priv/words.txt"

  @doc """
  Set the internal state with a random word, or the one provided for testing fun.
  """
  def start() do
    # Just read the word list every time, no point in caching it for our purposes

    File.read!(@word_file)
    |> String.split()
    |> Enum.reject(&String.starts_with?(&1, "#"))
    |> Enum.random()
    |> _start()
  end

  def start(word), do: _start(word)

  #

  @doc """
  Init state with the given word.
  """
  def _start(word) do
    word = String.upcase(word)
    state = %State{word: to_charlist(word)}
    init_state(state)

    :ok
  end

  @doc """
  Starts an Agent to hold state for this play (an instance of the %State{} struct).
  """
  def init_state(state) do
    case Process.whereis(__MODULE__) do
      nil ->
        IO.puts("Starting agent #{__MODULE__}")
        {:ok, _pid} = Agent.start(fn -> state end, name: __MODULE__)

      _ ->
        IO.puts("Stopping and starting agent #{__MODULE__}")
        :ok = Agent.stop(__MODULE__)
        {:ok, _pid} = Agent.start(fn -> state end, name: __MODULE__)
    end
  end

  def get_state() do
    Agent.get(__MODULE__, fn state -> state end)
  end

  def update_state(state) do
    :ok = Agent.update(__MODULE__, fn _state -> state end)
  end

  #

  @doc """
  Guesses a word, up to six tries.
  """
  def guess(guess) do
    get_state()
    |> _guess(String.upcase(guess))
    |> update_state()

    :ok
  end

  #

  @doc """
  Processes a guess and outputs the current guess results.
  """
  def _guess(state = %State{game_over: true}, _guess) do
    IO.puts("Game has been completed")

    state
  end

  def _guess(state, guess) do
    state = _process_guess(state, guess)

    # output(state.guesses)
    output(state.guesses, state.game_over)

    state
  end

  @doc """
  Does the heavy lifting of checking the guess against the word being guessed.
  """
  def _process_guess(state = %State{}, guess) do
    # IO.puts("Guess: #{guess}. State: #{inspect(state)}")

    # ARISE
    guess_cl = to_charlist(guess)

    # SRAQE
    word_cl = state.word
    # IO.inspect(word_cl, label: "word_cl")

    # One-based for sanity when thinking of the board as a human
    locs_to_check = [1, 2, 3, 4, 5]

    # Exact matches
    {exact_locs, word_cl} = find_exact_matches(locs_to_check, guess_cl, word_cl)

    # Remove the exact_locs match indices from consideration for inexact (aka other)
    # [1, 3, 4]
    locs_to_check = locs_to_check -- exact_locs

    # Other matches
    other_locs = find_other_matches(locs_to_check, guess_cl, word_cl)

    # The code formatting here is by way of the ElixirLS Extension
    state =
      %State{
        state
        | num_guessed: state.num_guessed + 1,
          guesses:
            state.guesses ++
              [[guess: guess, exact_locs: exact_locs, other_locs: other_locs]]
      }

    state =
      if state.num_guessed == 6 or length(exact_locs) == 5 do
        %{state | game_over: true}
      else
        state
      end

    state
  end

  @doc """
  Returns a list of the 1-based indices of guessed letters in the correct
  position (green-output guesses). Ensures that exact matches in the target
  word won't be found when checking of inexact matches by clearing the exact
  match letters.
  """
  def find_exact_matches(locs_to_check, guess_cl, word_cl) do
    # [2, 5]
    exact_locs =
      locs_to_check
      |> List.foldl([], fn n, acc ->
        if Enum.at(guess_cl, n - 1) == Enum.at(word_cl, n - 1) do
          # Not worrying about concat'ing rather than prepending and reversing
          acc ++ [n]
        else
          acc
        end
      end)

    # [2, 5]
    # IO.inspect(exact_locs, label: "Exact")

    # Clear the exact_locs matches in word_cl so they're not found when looking for
    # other matches
    # S.AQ.
    word_cl =
      exact_locs
      |> List.foldl(word_cl, fn loc, acc -> List.replace_at(acc, loc - 1, ?.) end)

    # IO.inspect(word_cl, label: "Now word_cl")

    {exact_locs, word_cl}
  end

  @doc """
  Returns a list of the 1-based indices of guessed letters that are in the
  target word but not in correct position (yellow-output guesses).
  """
  def find_other_matches(locs_to_check, guess_cl, word_cl) do
    # For each guess_char that wasn't an exact match, see if it's one of the
    # other chars in word_cl.
    # If so, replace the word_cl char so it won't be found again, and save the
    # loc of the found char in acc.
    {other_locs, _word_cl} =
      locs_to_check
      |> List.foldl({[], word_cl}, fn n, {other_locs, word_cl} ->
        guess_char = Enum.at(guess_cl, n - 1)
        word_idx = Enum.find_index(word_cl, fn c -> c == guess_char end)

        acc =
          if word_idx != nil do
            other_locs = other_locs ++ [n]
            word_cl = List.replace_at(word_cl, word_idx, ?.)

            {other_locs, word_cl}
          else
            # Unchanged
            {other_locs, word_cl}
          end

        acc
      end)

    other_locs
  end

  @doc """
  Outputs the guesses so far, color coded in proper Wordle fashion- green
  for letters in correct spot, yellow for wrong spot, and uncolored for
  letters not in the word.

  This shows the internal state after six guesses- each guess adds an element
  to the list. The sixth guess here correctly picked SHEAR, as seen by other_locs
  being empty.
  [
    [guess: "ARISE", exact_locs: [], other_locs: [1, 2, 4, 5]],
    [guess: "STARE", exact_locs: [1], other_locs: [3, 4, 5]],
    [guess: "SAFER", exact_locs: [1, 5], other_locs: [2, 4]],
    [guess: "SEWAR", exact_locs: [1, 4, 5], other_locs: [2]],
    [guess: "SPEAR", exact_locs: [1, 3, 4, 5], other_locs: []],
    [guess: "SHEAR", exact_locs: [1, 2, 3, 4, 5], other_locs: []]
  ]
  """
  def output(guesses, game_over?) do
    # IO.inspect(guesses, label: "guesses")

    out =
      guesses
      |> Enum.map(fn guess ->
        # IO.inspect(guess, label: "guess")

        guess_cl = to_charlist(guess[:guess])
        # [1, 5]
        exact_locs = guess[:exact_locs]
        # [2, 4]
        other_locs = guess[:other_locs]

        # Pair exact matches with the atom :exact for use below
        # SAFER
        # [{1, :exact}, {5, :exact}]
        exact_pairs = Enum.zip(exact_locs, List.duplicate(:exact, length(exact_locs)))

        # Pair other matches with the atom :other for use below
        # [{2, :other}, {4, :other}]
        other_pairs = Enum.zip(other_locs, List.duplicate(:other, length(other_locs)))

        # Pair unmatched letters with the atom :none for use below0
        # [{3, :none}]
        no_match_locs = [1, 2, 3, 4, 5] -- (exact_locs ++ other_locs)
        # no_match_pairs = Enum.zip(no_match_locs, List.duplicate(?\s, length(no_match_locs)))
        no_match_pairs = Enum.zip(no_match_locs, List.duplicate(:none, length(no_match_locs)))

        # Combine those three zipped lists, and sort so they're ordered by
        # position for use below
        # [{1, :exact}, {2, :other}, {3, :none}, {4, :other}, {5, :exact}]
        all_pairs =
          (exact_pairs ++ other_pairs ++ no_match_pairs)
          |> Enum.sort()

        # Use colorize_char/2 to properly color code the letter using
        # the atom flags set above (:exact, :other, :none)
        out_pairs =
          Enum.zip_with(all_pairs, guess_cl, fn {_n, which}, char ->
            colorize_char(which, char)
          end)
          |> Enum.intersperse(~c" ")

        out_pairs
      end)

    rows_left = 6 - length(guesses)

    out =
      if rows_left > 0 and not game_over? do
        out ++ List.duplicate(["___ ___ ___ ___ ___"], rows_left)
      else
        out
      end

    # out = (out ++ blanks) |> Enum.join("\n")
    out = Enum.join(out, "\n")

    IO.puts(out)

    if game_over? do
      if rows_left > 0 do
        IO.puts("Congratulations!!")
      else
        IO.puts("Better luck next time!!")
      end
    end
  end

  def colorize_char(:exact, char) do
    IO.ANSI.format([:green_background, " #{List.to_string([char])} "])
  end

  def colorize_char(:other, char) do
    IO.ANSI.format([:yellow_background, " #{List.to_string([char])} "])
  end

  def colorize_char(:none, char) do
    " #{List.to_string([char])} "
  end

  ###

  @doc """
  INITIAL VERSION FOR PROOF OF CONCEPT, BEFORE THEN COLORIZING IT

  guesses on the 6th and successful guess:
  [
    [guess: "ARISE", exact_locs: [], other_locs: [1, 2, 4, 5]],
    [guess: "STARE", exact_locs: [1], other_locs: [3, 4, 5]],
    [guess: "SAFER", exact_locs: [1, 5], other_locs: [2, 4]],
    [guess: "SEWAR", exact_locs: [1, 4, 5], other_locs: [2]],
    [guess: "SPEAR", exact_locs: [1, 3, 4, 5], other_locs: []],
    [guess: "SHEAR", exact_locs: [1, 2, 3, 4, 5], other_locs: []]
  ]

  Out:
  :A :R  I :S :E
  =S  T :A :R :E
  =S :A  F :E =R
  =S :E  W =A =R
  =S  P =E =A =R
  =S =H =E =A =R
  """
  def _output_original(guesses) do
    # IO.inspect(guesses, label: "guesses")

    out =
      guesses
      |> Enum.map(fn guess ->
        # IO.inspect(guess, label: "guess")

        guess_cl = to_charlist(guess[:guess])
        # [1, 5]
        exact_locs = guess[:exact_locs]
        # [2, 4]
        other_locs = guess[:other_locs]

        # SAFER
        # [{1, 61}, {5, 61}]
        exact_pairs = Enum.zip(exact_locs, List.duplicate(?=, length(exact_locs)))

        # [{2, 58}, {4, 58}]
        other_pairs = Enum.zip(other_locs, List.duplicate(?:, length(other_locs)))

        # [{3, 32}]
        no_match_locs = [1, 2, 3, 4, 5] -- (exact_locs ++ other_locs)
        no_match_pairs = Enum.zip(no_match_locs, List.duplicate(?\s, length(no_match_locs)))

        # [{1, 61}, {2, 58}, {3, 32}, {4, 58}, {5, 61}]
        all_pairs =
          (exact_pairs ++ other_pairs ++ no_match_pairs)
          |> Enum.sort()

        # [~c"=S", ~c":A", ~c" F", ~c":E", ~c"=R"]
        out_pairs =
          Enum.zip_with(all_pairs, guess_cl, fn {_n, label}, char -> [label, char] end)
          # [~c"=S", ~c" ", ~c":A", ~c" ", ~c" F", ~c" ", ~c":E", ~c" ", ~c"=R"]
          |> Enum.intersperse(~c" ")

        out_pairs
        # ~c"=S :A  F :E =R"
        |> List.flatten()
        #
        # "=S :A  F :E =R"
        |> to_string()
      end)

    out =
      out
      |> Enum.join("\n")

    IO.puts(out)
  end
end
