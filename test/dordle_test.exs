defmodule DordleTest do
  use ExUnit.Case
  # doctest Dordle

  test "find_exact_matches" do
    locs_to_check = [0, 1, 2, 3, 4]
    # guess_cl = ~c"ARISE"
    word_cl = ~c"SRAQE"

    {exact_idxs, word_cl_out} = Dordle.find_exact_matches(locs_to_check, ~c"ZZZZZ", word_cl)
    assert exact_idxs == []
    assert word_cl_out == ~c"SRAQE"

    {exact_idxs, word_cl_out} = Dordle.find_exact_matches(locs_to_check, ~c"ZZZZE", word_cl)
    assert exact_idxs == [4]
    assert word_cl_out == ~c"SRAQ."

    {exact_idxs, word_cl_out} = Dordle.find_exact_matches(locs_to_check, ~c"ZRZZE", word_cl)
    assert exact_idxs == [1, 4]
    assert word_cl_out == ~c"S.AQ."
  end

  test "find_other_matches" do
    locs_to_check = [0, 1, 2, 3, 4]
    # guess_cl = ~c"ARISE"
    word_cl = ~c"SRAQE"

    # None
    other_idxs = Dordle.find_other_matches(locs_to_check, ~c"ZZZZZ", word_cl)
    assert other_idxs == []

    # This test right here is not the expected case, but where locs_to_check
    # includes locs where there's an exact match. Normally, locs_to_check would
    # exclude 1, since R is an exact match.
    other_idxs = Dordle.find_other_matches(locs_to_check, ~c"ZREZZ", word_cl)
    assert other_idxs == [1, 2]

    # Now where locs_to_check correctly excludes 1
    locs_to_check = [0, 2, 3, 4]
    other_idxs = Dordle.find_other_matches(locs_to_check, ~c"ZREZZ", word_cl)
    assert other_idxs == [2]

    # With two others
    locs_to_check = [0, 1, 2, 3, 4]
    other_idxs = Dordle.find_other_matches(locs_to_check, ~c"EZQZZ", word_cl)
    assert other_idxs == [0, 2]
  end

  test "guess none" do
    state = Dordle.start("SRAQE")
    state = Dordle.guess(state, "ZZZZZ")

    assert state ==
             %State{
               game_over: false,
               word: ~c"SRAQE",
               num_guessed: 1,
               guesses: [[guess: "ZZZZZ", exact_idxs: [], other_idxs: []]]
             }
  end

  test "guess ARISE - 2 exact, 1 other" do
    state = Dordle.start("SRAQE")
    state = Dordle.guess(state, "ARISE")

    assert state ==
             %State{
               game_over: false,
               word: ~c"SRAQE",
               num_guessed: 1,
               guesses: [[guess: "ARISE", exact_idxs: [1, 4], other_idxs: [0, 3]]]
             }
  end

  test "guess 2 exact, 0 other" do
    state = Dordle.start("SRAQE")
    state = Dordle.guess(state, "SZZQZ")

    assert state ==
             %State{
               game_over: false,
               word: ~c"SRAQE",
               num_guessed: 1,
               guesses: [[guess: "SZZQZ", exact_idxs: [0, 3], other_idxs: []]]
             }
  end

  test "guess 5 exact, 0 other" do
    state = Dordle.start("SRAQE")
    state = Dordle.guess(state, "SRAQE")

    assert state ==
             %State{
               game_over: true,
               word: ~c"SRAQE",
               num_guessed: 1,
               guesses: [[guess: "SRAQE", exact_idxs: [0, 1, 2, 3, 4], other_idxs: []]]
             }
  end

  test "guess 0 exact, 2 other" do
    state = Dordle.start("SRAQE")
    state = Dordle.guess(state, "ZSQZZ")

    assert state ==
             %State{
               game_over: false,
               word: ~c"SRAQE",
               num_guessed: 1,
               guesses: [[guess: "ZSQZZ", exact_idxs: [], other_idxs: [1, 2]]]
             }
  end

  test "guess 0 exact, 5 other" do
    state = Dordle.start("SRAQE")
    state = Dordle.guess(state, "RAQES")

    assert state ==
             %State{
               game_over: false,
               word: ~c"SRAQE",
               num_guessed: 1,
               guesses: [[guess: "RAQES", exact_idxs: [], other_idxs: [0, 1, 2, 3, 4]]]
             }
  end

  test "guess 2 exact, 2 other" do
    state = Dordle.start("SRAQE")
    state = Dordle.guess(state, "SAZQR")

    assert state ==
             %State{
               game_over: false,
               word: ~c"SRAQE",
               num_guessed: 1,
               guesses: [[guess: "SAZQR", exact_idxs: [0, 3], other_idxs: [1, 4]]]
             }
  end

  test "guess 2 exact, 3 other" do
    state = Dordle.start("ABCDE")
    state = Dordle.guess(state, "CBEDA")

    assert state ==
             %State{
               game_over: false,
               word: ~c"ABCDE",
               num_guessed: 1,
               guesses: [[guess: "CBEDA", exact_idxs: [1, 3], other_idxs: [0, 2, 4]]]
             }
  end

  test "guess to completion" do
    state = Dordle.start("MNOPQ")

    state =
      Dordle.guess(state, "AAAAA")
      |> Dordle.guess("BBBBB")
      |> Dordle.guess("CCCCC")
      |> Dordle.guess("DDDDD")
      |> Dordle.guess("EEEEE")
      |> Dordle.guess("FFFFF")

    assert state ==
             %State{
               game_over: true,
               word: ~c"MNOPQ",
               num_guessed: 6,
               guesses: [
                 [guess: "AAAAA", exact_idxs: [], other_idxs: []],
                 [guess: "BBBBB", exact_idxs: [], other_idxs: []],
                 [guess: "CCCCC", exact_idxs: [], other_idxs: []],
                 [guess: "DDDDD", exact_idxs: [], other_idxs: []],
                 [guess: "EEEEE", exact_idxs: [], other_idxs: []],
                 [guess: "FFFFF", exact_idxs: [], other_idxs: []]
               ]
             }
  end

  #

  test "guess CREST 4/14/24" do
    state = Dordle.start("CREST")

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ARISE", exact_idxs: [1, 3], other_idxs: [4]]]
             },
             Dordle.guess(state, "ARISE")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "FRESH", exact_idxs: [1, 2, 3], other_idxs: []]]
             },
             Dordle.guess(state, "FRESH")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "WREST", exact_idxs: [1, 2, 3, 4], other_idxs: []]]
             },
             Dordle.guess(state, "WREST")
           )

    assert match?(
             %State{
               game_over: true,
               guesses: [[guess: "CREST", exact_idxs: [0, 1, 2, 3, 4], other_idxs: []]]
             },
             Dordle.guess(state, "CREST")
           )
  end

  test "guess LAUGH 4/13/24" do
    state = Dordle.start("LAUGH")

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ARISE", exact_idxs: [], other_idxs: [0]]]
             },
             Dordle.guess(state, "ARISE")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "CHANT", exact_idxs: [], other_idxs: [1, 2]]]
             },
             Dordle.guess(state, "CHANT")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "GAUCH", exact_idxs: [1, 2, 4], other_idxs: [0]]]
             },
             Dordle.guess(state, "GAUCH")
           )

    assert match?(
             %State{
               game_over: true,
               guesses: [[guess: "LAUGH", exact_idxs: [0, 1, 2, 3, 4], other_idxs: []]]
             },
             Dordle.guess(state, "LAUGH")
           )
  end

  test "guess NURSE 4/12/24" do
    state = Dordle.start("NURSE")

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ARISE", exact_idxs: [3, 4], other_idxs: [1]]]
             },
             Dordle.guess(state, "ARISE")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ROUSE", exact_idxs: [3, 4], other_idxs: [0, 2]]]
             },
             Dordle.guess(state, "ROUSE")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "PURSE", exact_idxs: [1, 2, 3, 4], other_idxs: []]]
             },
             Dordle.guess(state, "PURSE")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "CURSE", exact_idxs: [1, 2, 3, 4], other_idxs: []]]
             },
             Dordle.guess(state, "CURSE")
           )

    assert match?(
             %State{
               game_over: true,
               guesses: [[guess: "NURSE", exact_idxs: [0, 1, 2, 3, 4], other_idxs: []]]
             },
             Dordle.guess(state, "NURSE")
           )
  end

  test "guess ARROW 4/11/24" do
    state = Dordle.start("ARROW")

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ARISE", exact_idxs: [0, 1], other_idxs: []]]
             },
             Dordle.guess(state, "ARISE")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ARMOR", exact_idxs: [0, 1, 3], other_idxs: [4]]]
             },
             Dordle.guess(state, "ARMOR")
           )

    assert match?(
             %State{
               game_over: true,
               guesses: [[guess: "ARROW", exact_idxs: [0, 1, 2, 3, 4], other_idxs: []]]
             },
             Dordle.guess(state, "ARROW")
           )
  end

  test "guess TURBO 4/10/24" do
    state = Dordle.start("TURBO")

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ARISE", exact_idxs: [], other_idxs: [1]]]
             },
             Dordle.guess(state, "ARISE")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ROUND", exact_idxs: [], other_idxs: [0, 1, 2]]]
             },
             Dordle.guess(state, "ROUND")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "FLOUR", exact_idxs: [], other_idxs: [2, 3, 4]]]
             },
             Dordle.guess(state, "FLOUR")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "CURIO", exact_idxs: [1, 2, 4], other_idxs: []]]
             },
             Dordle.guess(state, "CURIO")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "BURRO", exact_idxs: [1, 2, 4], other_idxs: [0]]]
             },
             Dordle.guess(state, "BURRO")
           )

    assert match?(
             %State{
               game_over: true,
               guesses: [[guess: "TURBO", exact_idxs: [0, 1, 2, 3, 4], other_idxs: []]]
             },
             Dordle.guess(state, "TURBO")
           )
  end

end
