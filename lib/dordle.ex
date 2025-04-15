defmodule Dordle do
  @moduledoc """
  Documentation for `Dordle`.
  """

  @doc """
  """
  def start(), do: start("SRAQE")

  def start(word) do
    # TODO: setting the word
    # TODO: rot13 the word

    # Using fake word just so can test with two exact matches and two other
    # with a guess of ARISE. Exact: R and E. Other: A and S
    # %State{word: ~c"SRAQE"}
    %State{word: to_charlist(word)}
  end

  #

  def guess(state = %State{game_over: true}, _guess) do
    IO.puts("Game has been completed")

    state
  end

  # def guess(state = %State{}, _guess) when state.num_guessed == 6 do
  #   IO.puts("Game has been completed")

  #   {:result, %{state | game_over: true}}
  # end

  def guess(state = %State{}, guess) do
    # IO.puts("Guess: #{guess}. State: #{inspect(state)}")

    # ARISE
    guess_cl = to_charlist(guess)

    # SRAQE
    word_cl = state.word
    # IO.inspect(word_cl, label: "word_cl")

    locs_to_check = [0, 1, 2, 3, 4]

    # Exact matches
    {exact_idxs, word_cl} = find_exact_matches(locs_to_check, guess_cl, word_cl)

    # Remove the exact_idxs match indices from consideration for inexact (aka other)
    # [0, 2, 3]
    locs_to_check = locs_to_check -- exact_idxs

    # Other matches
    other_idxs = find_other_matches(locs_to_check, guess_cl, word_cl)

    state =
      %{
        state
        | num_guessed: state.num_guessed + 1,
          guesses:
            state.guesses ++
              [[guess: guess, exact_idxs: exact_idxs, other_idxs: other_idxs]]
      }

    state =
      if state.num_guessed == 6 or length(exact_idxs) == 5 do
        %{state | game_over: true}
      else
        state
      end

    state
  end

  def find_exact_matches(locs_to_check, guess_cl, word_cl) do
    exact_idxs =
      locs_to_check
      |> List.foldl([], fn n, acc ->
        if Enum.at(guess_cl, n) == Enum.at(word_cl, n) do
          # Not worrying about concat'ing rather than prepending and reversing
          acc ++ [n]
        else
          acc
        end
      end)

    # [1, 4]
    # IO.inspect(exact_idxs, label: "Exact")

    # Clear the exact_idxs matches in word_cl so they're not found when looking for
    # other matches
    # S.AQ.
    word_cl =
      exact_idxs
      |> List.foldl(word_cl, fn idx, acc -> List.replace_at(acc, idx, ?.) end)

    # IO.inspect(word_cl, label: "Now word_cl")

    {exact_idxs, word_cl}
  end

  def find_other_matches(locs_to_check, guess_cl, word_cl) do
    # For each guess_char that wasn't an exact match, see if it's one of the
    # other chars in word_cl.
    # If so, replace the word_cl char so it won't be found again, and save the
    # index of the found char in acc.
    {other_idxs, _word_cl} =
      locs_to_check
      |> List.foldl({[], word_cl}, fn n, {other_idxs, word_cl} ->
        guess_char = Enum.at(guess_cl, n)
        word_idx = Enum.find_index(word_cl, fn c -> c == guess_char end)

        acc =
          if word_idx != nil do
            other_idxs = other_idxs ++ [n]
            word_cl = List.replace_at(word_cl, word_idx, ?.)

            {other_idxs, word_cl}
          else
            # Unchanged
            {other_idxs, word_cl}
          end

        acc
      end)

    other_idxs
  end
end
