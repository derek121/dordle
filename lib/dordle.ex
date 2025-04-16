defmodule Dordle do
  @moduledoc """
  """

  @doc """
  """
  def start(), do: start("SHEAR")

  def start(word) do
    word = String.upcase(word)

    # TODO: setting the word
    # TODO: rot13 the word
    # TODO: keep state in an Agent?

    # Using fake word just so can test with two exact matches and two other
    # with a guess of ARISE. Exact: R and E. Other: A and S
    # %State{word: ~c"SRAQE"}
    state = %State{word: to_charlist(word)}

    init_state(state)

    :ok
  end

  def init_state(state) do
    case Process.whereis(__MODULE__) do
      nil ->
        IO.puts("Starting agent #{__MODULE__}")
        {:ok, _pid} = Agent.start(fn -> state end, name: __MODULE__)

      _ ->
        IO.puts("Stopping and starting agen #{__MODULE__}")
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

  def guess(guess) do
    get_state()
    |> guess(String.upcase(guess))
    |> update_state()

    :ok
  end

  #

  def guess(state = %State{game_over: true}, _guess) do
    IO.puts("Game has been completed")

    state
  end

  def guess(state, guess) do
    state = process_guess(state, guess)

    output(state.guesses)

    state
  end

  # def process_guess(state = %State{game_over: true}, _guess) do
  #   IO.puts("Game has been completed")

  #   state
  # end

  # def process_guess(state = %State{}, _guess) when state.num_guessed == 6 do
  #   IO.puts("Game has been completed")

  #   {:result, %{state | game_over: true}}
  # end

  def process_guess(state = %State{}, guess) do
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

  guesses:
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
  def output(guesses) do
    out =
      guesses
      |> Enum.map(fn guess ->
        guess_cl = to_charlist(guess[:guess])
        exact_locs = guess[:exact_locs]
        other_locs = guess[:other_locs]

        # SEWAR
        # [{1, 61}, {4, 61}, {5, 61}]
        exact_pairs = Enum.zip(exact_locs, List.duplicate(?=, length(exact_locs)))

        # [{2, 58}]
        other_pairs = Enum.zip(other_locs, List.duplicate(?:, length(other_locs)))

        # [{3, 46}]
        no_match_locs = [1, 2, 3, 4, 5] -- (exact_locs ++ other_locs)
        no_match_pairs = Enum.zip(no_match_locs, List.duplicate(?\s, length(no_match_locs)))

        # [{1, 61}, {2, 58}, {3, 46}, {4, 61}, {5, 61}]
        all_pairs =
          (exact_pairs ++ other_pairs ++ no_match_pairs)
          |> Enum.sort()

        # [~c"=S", ~c":E", ~c" W", ~c"=A", ~c"=R"]
        out_pairs =
          Enum.zip_with(all_pairs, guess_cl, fn {_n, c}, y -> [c, y] end)
          |> Enum.intersperse(~c" ")

        out_pairs
        # ~c"=S :E  W =A =R"
        |> List.flatten()
        #
        # "=S :E  W =A =R"
        |> to_string()
      end)

    out =
      out
      |> Enum.join("\n")

    IO.puts(out)
  end

  def find_exact_matches(locs_to_check, guess_cl, word_cl) do
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
end
