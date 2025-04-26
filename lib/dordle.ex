defmodule Dordle do
  @moduledoc """
  Implementation of the word game Wordle. Six guesses to find the target
  5-letter word. After each guess the guesses so far are output, each
  letter color-coded green if it's in the word and in the correct spot; yellow
  if it's in the word but in the wrong spot; and no color if it's not in the
  word at all.
  """

  # TODO: Optional start param of max num guesses

  @word_file "priv/words.txt"

  @doc """
  Set the internal state with a random word, or the one provided for fun or
  testing.
  """
  def start() do
    # Just read the word list every time, no point in caching it for our purposes

    File.read!(@word_file)
    |> String.split(["\r", "\n"], trim: true)
    |> Enum.reject(&String.starts_with?(&1, "#"))
    |> Enum.random()
    |> _start()
  end

  # Don't just fail-fast, but give a nice message instead of Crashing, since
  # this is user-facing
  def start(word = <<_, _, _, _, _>>) do
    # Can't using String.length/1 in a guard, but the above is fine
    _start(word)
  end

  def start(_word) do
    IO.puts("Error: Word must be of length five")
  end

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
        # IO.puts("Starting agent #{__MODULE__}")
        {:ok, _pid} = Agent.start(fn -> state end, name: __MODULE__)

      _ ->
        # IO.puts("Stopping and starting agent #{__MODULE__}")
        :ok = Agent.stop(__MODULE__)
        {:ok, _pid} = Agent.start(fn -> state end, name: __MODULE__)
    end
  end

  # For testing
  def get_state() do
    Agent.get(__MODULE__, fn state -> state end)
  end

  def update_state(state) do
    :ok = Agent.update(__MODULE__, fn _state -> state end)
  end

  #

  @doc """
  Top-level call- guesses a word, up to six tries, and prints result.
  """
  def guess(guess = <<_, _, _, _, _>>) do
    # Can't using String.length/1 in a guard, but the above is fine
    get_state()
    |> _guess(String.upcase(guess))
    |> update_state()

    :ok
  end

  def guess(_guess) do
    IO.puts("Error: Guess must be of length five")
  end

  #

  @doc """
  Processes a guess and outputs the current guess results.
  """
  def _guess(state = %State{game_over?: true}, _guess) do
    IO.puts("Game has been completed")

    state
  end

  def _guess(state, guess) do
    state = _process_guess(state, guess)

    output(state.word, state.guesses, state.game_over?)

    state
  end

  @doc """
  Does the heavy lifting of checking the guess against the word being guessed,
  updating and returning state.
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

    # Note on clearing and removing letter indices from consideration:
    # Remove the exact_locs match indices from consideration for inexact (aka other)
    # Otherwise, we'd have the situation like where the word to guess is ARROW
    # and the guess is ARISE. The R in pos 2 is an exact match, but if we don't
    # exclude it here from locs_to_check for other (inexact) matches, it would match
    # the second R in ARROW (the first R in ARROW won't be matched because of it
    # being cleared in find_exact_matches/3).
    #
    # So-
    # 1: The clearing of the exact match in word_cl in find_exact_matches/3
    # prevents an exact match being found by the same letter in an inexact
    # position in the guess.
    # E.g., if word_cl was ARISE and the guess was ARROW, we'd otherwise match
    # the second R of ARROW with the already-matched R in ARISE.
    # And:
    # 2: The exclusion here of exact_locs from
    # locs_to_check prevents a given character in the guess that was an exact
    # match from matching a different instance of that letter in word_cl.
    # E.g., if word_cl was ARROW, and the guess was ARISE, we'd otherwise match
    # in find_other_matches/3 the R in ARISE, already used as an exact match,
    # with the second R in ARROW.

    # [1, 3, 4]
    locs_to_check = locs_to_check -- exact_locs

    # Other matches
    other_locs = find_other_matches(locs_to_check, guess_cl, word_cl)

    # (the code formatting here is by way of the ElixirLS Extension)
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
        %{state | game_over?: true}
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

  See "Note on clearing and removing letter indices from consideration" in
  _process_guess/2 for details.
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
    # *** See "Note on clearing and removing letter indices from consideration" in
    # _process_guess/2 for details.
    # S.AQ.
    word_cl =
      exact_locs
      |> List.foldl(word_cl, fn loc, acc -> List.replace_at(acc, loc - 1, ?.) end)

    # IO.inspect(word_cl, label: "Now word_cl")

    {exact_locs, word_cl}
  end

  @doc """
  Returns a list of the 1-based indices of guessed letters that are in the
  target word but not in correct position (yellow-output guesses). As
  mentioned in the comment for find_exact_matches/3, word_cl has the
  characters that were exact matches cleared so we won't match them here
  incorrectly.

  See "Note on clearing and removing letter indices from consideration" in
  _process_guess/2 for details.
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

            # Replace it in word_cl so we don't find it more than once
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
  def output(answer, guesses, game_over?) do
    # IO.inspect(guesses, label: "guesses")

    # [
    #   [{65, :exact}, {82, :exact}, {73, :none}, {83, :none}, {69, :other}],
    #   [{90, :none}, {90, :none}, {83, :none}, {90, :none}, {90, :none}],
    #   [{90, :none}, {90, :none}, {78, :other}, {90, :none}, {90, :none}],
    #   ...
    # ]
    rows_chars_to_which = create_rows_chars_to_which(guesses)
    # IO.inspect(rows_chars_to_which, label: "rows....")

    output_rows = colorize_rows(rows_chars_to_which)
    # |> IO.inspect(label: "OUT")

    rows_left = 6 - length(output_rows)

    output_rows =
      #if rows_left > 0 and not game_over? do
      if rows_left > 0 do
        output_rows ++ List.duplicate(["___ ___ ___ ___ ___"], rows_left)
      else
        output_rows
      end

    # Space the rows over to be centered over the keyboard below
    output_rows = add_prefix_centering_spaces_to_rows(output_rows)

    output_rows = Enum.join(output_rows, "\n")

    IO.puts(output_rows)

    if not game_over? do
      IO.puts("")
      IO.puts("")
      output_keyboard(rows_chars_to_which)
    else
      if rows_left > 0 or length(Enum.at(guesses, 5)[:exact_locs]) == 5 do
        IO.puts("")
        IO.puts("Congratulations!!")
      else
        IO.puts("")
        output_answer(answer)
        IO.puts("")
        IO.puts("Better luck next time!!")
      end
    end
  end

  @doc """
  Space the rows over to be centered over the keyboard below.
  """
  def add_prefix_centering_spaces_to_rows(rows) do
    Enum.map(rows, &add_prefix_centering_spaces_to_row/1)
  end

  def add_prefix_centering_spaces_to_row(row) do
    ["          ", row]
  end

  def output_answer(answer) do
    Enum.zip(
      answer,
      # Length will always be 5
      List.duplicate(:answer, 5)
    )
    |> colorize_row()
    |> add_prefix_centering_spaces_to_row()
    |> IO.puts()
  end

  @doc """
  For each guess, map each character to a tuple with an atom indicating how it
  matches the word- a match in the right position (:exact), a match but not in
  the right position (:other), or not in the word at all (:none).

  Out:
  [
    [{65, :exact}, {82, :exact}, {73, :none}, {83, :none}, {69, :other}],
    [{90, :none}, {90, :none}, {83, :none}, {90, :none}, {90, :none}],
    [{90, :none}, {90, :none}, {78, :other}, {90, :none}, {90, :none}],
    ...
  ]
  """
  def create_rows_chars_to_which(guesses) do
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

      # [{65, :exact}, {82, :other}, {73, :none}, {83, :none}, {69, :none}]
      char_to_which =
        Enum.zip_with(all_pairs, guess_cl, fn {_n, which}, char ->
          {char, which}
        end)

      char_to_which
      # |> IO.inspect(label: "char_to_which")
    end)
  end

  @doc """
  In:
  [
    [{65, :exact}, {82, :other}, {73, :none}, {83, :none}, {69, :none}],
    [{82, :other}, {73, :none}, {78, :other}, {71, :none}, {83, :none}],
    ...
  ]

  Out:
  List of iolists representing the colorized output.
  """
  def colorize_rows(rows_chars_to_which) do
    rows_chars_to_which
    |> Enum.map(&colorize_row/1)
  end

  @doc """
  In:
  [{65, :exact}, {82, :other}, {73, :none}, {83, :none}, {69, :none}]
  """
  def colorize_row(row) do
    row
    |> Enum.map(fn {char, which} ->
      colorize_char(which, char)
    end)
    |> Enum.intersperse(~c" ")
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

  def colorize_char(:answer, char) do
    IO.ANSI.format([:cyan_background, " #{List.to_string([char])} "])
  end

  @doc """
  Output the keyboad with the letters being color-coded green if it has been
  found, even if it was subsequently guessed in a different position (yellow).
  Colored yellow if found an not an exact match, and no color otherwise.

  In:
  [
    [{65, :exact}, {82, :other}, {73, :none}, {83, :none}, {69, :none}],
    [{82, :other}, {73, :none}, {78, :other}, {71, :none}, {83, :none}],
    ...
  ]

  Out:
  An ANSI-formatted IOData list to be output.
  """
  def output_keyboard(rows_chars_to_which) do
    all =
      rows_chars_to_which
      |> List.flatten()

    # %{65 => :exact}
    exact_matches =
      all
      |> Enum.filter(fn {_char, which} -> which == :exact end)
      |> Map.new()

    # |> IO.inspect(label: "Exact")

    # %{69 => :other, 83 => :other}
    other_matches =
      all
      |> Enum.filter(fn {_char, which} -> which == :other end)
      |> Map.new()

    # |> IO.inspect(label: "Other")

    # %{?A => :none, ...} for all 26 letters
    none_matches =
      Enum.zip(Range.to_list(?A..?Z), List.duplicate(:none, 26))
      |> Map.new()

    # Prefer exact
    # %{65 => :exact, 69 => :other, 83 => :other}
    matches =
      none_matches
      |> Map.merge(other_matches)
      |> Map.merge(exact_matches)

    to_colorize =
      [
        [
          {?Q, matches[?Q]},
          {?W, matches[?W]},
          {?E, matches[?E]},
          {?R, matches[?R]},
          {?T, matches[?T]},
          {?Y, matches[?Y]},
          {?U, matches[?U]},
          {?I, matches[?I]},
          {?O, matches[?O]},
          {?P, matches[?P]}
        ],
        [
          {?A, matches[?A]},
          {?S, matches[?S]},
          {?D, matches[?D]},
          {?F, matches[?F]},
          {?G, matches[?G]},
          {?H, matches[?H]},
          {?J, matches[?J]},
          {?K, matches[?K]},
          {?L, matches[?L]}
        ],
        [
          {?Z, matches[?Z]},
          {?X, matches[?X]},
          {?C, matches[?C]},
          {?V, matches[?V]},
          {?B, matches[?B]},
          {?N, matches[?N]},
          {?M, matches[?M]}
        ]
      ]

    # Add blank prefixes so the three rows are centered with each other
    [q_row, a_row, z_row] = colorize_rows(to_colorize)

    colorized =
      [
        q_row,
        ["  "] ++ a_row,
        ["      "] ++ z_row
      ]
      |> Enum.join("\n")

    IO.puts(colorized)
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
