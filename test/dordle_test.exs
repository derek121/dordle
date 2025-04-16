defmodule DordleTest do
  use ExUnit.Case
  # doctest Dordle

  test "find_exact_matches" do
    locs_to_check = [1, 2, 3, 4, 5]
    # guess_cl = ~c"ARISE"
    word_cl = ~c"SRAQE"

    {exact_locs, word_cl_out} = Dordle.find_exact_matches(locs_to_check, ~c"ZZZZZ", word_cl)
    assert exact_locs == []
    assert word_cl_out == ~c"SRAQE"

    {exact_locs, word_cl_out} = Dordle.find_exact_matches(locs_to_check, ~c"ZZZZE", word_cl)
    assert exact_locs == [5]
    assert word_cl_out == ~c"SRAQ."

    {exact_locs, word_cl_out} = Dordle.find_exact_matches(locs_to_check, ~c"ZRZZE", word_cl)
    assert exact_locs == [2, 5]
    assert word_cl_out == ~c"S.AQ."
  end

  test "find_other_matches" do
    locs_to_check = [1, 2, 3, 4, 5]
    # guess_cl = ~c"ARISE"
    word_cl = ~c"SRAQE"

    # None
    other_locs = Dordle.find_other_matches(locs_to_check, ~c"ZZZZZ", word_cl)
    assert other_locs == []

    # This test right here is not the expected case, but where locs_to_check
    # includes locs where there's an exact match. Normally, locs_to_check would
    # exclude 1, since R is an exact match.
    other_locs = Dordle.find_other_matches(locs_to_check, ~c"ZREZZ", word_cl)
    assert other_locs == [2, 3]

    # Now where locs_to_check correctly excludes 2
    locs_to_check = [1, 3, 4, 5]
    other_locs = Dordle.find_other_matches(locs_to_check, ~c"ZREZZ", word_cl)
    assert other_locs == [3]

    # With two others
    locs_to_check = [1, 2, 3, 4, 5]
    other_locs = Dordle.find_other_matches(locs_to_check, ~c"EZQZZ", word_cl)
    assert other_locs == [1, 3]
  end

  test "process_guess none" do
    Dordle.start("SRAQE")
    state = Dordle.process_guess(Dordle.get_state(), "ZZZZZ")

    assert state ==
             %State{
               game_over: false,
               word: ~c"SRAQE",
               num_guessed: 1,
               guesses: [[guess: "ZZZZZ", exact_locs: [], other_locs: []]]
             }
  end

  test "process_guess ARISE - 2 exact, 1 other" do
    Dordle.start("SRAQE")
    state = Dordle.process_guess(Dordle.get_state(), "ARISE")

    assert state ==
             %State{
               game_over: false,
               word: ~c"SRAQE",
               num_guessed: 1,
               guesses: [[guess: "ARISE", exact_locs: [2, 5], other_locs: [1, 4]]]
             }
  end

  test "process_guess 2 exact, 0 other" do
    Dordle.start("SRAQE")
    state = Dordle.process_guess(Dordle.get_state(), "SZZQZ")

    assert state ==
             %State{
               game_over: false,
               word: ~c"SRAQE",
               num_guessed: 1,
               guesses: [[guess: "SZZQZ", exact_locs: [1, 4], other_locs: []]]
             }
  end

  test "process_guess 5 exact, 0 other" do
    Dordle.start("SRAQE")
    state = Dordle.process_guess(Dordle.get_state(), "SRAQE")

    assert state ==
             %State{
               game_over: true,
               word: ~c"SRAQE",
               num_guessed: 1,
               guesses: [[guess: "SRAQE", exact_locs: [1, 2, 3, 4, 5], other_locs: []]]
             }
  end

  test "process_guess 0 exact, 2 other" do
    Dordle.start("SRAQE")
    state = Dordle.process_guess(Dordle.get_state(), "ZSQZZ")

    assert state ==
             %State{
               game_over: false,
               word: ~c"SRAQE",
               num_guessed: 1,
               guesses: [[guess: "ZSQZZ", exact_locs: [], other_locs: [2, 3]]]
             }
  end

  test "process_guess 0 exact, 5 other" do
    Dordle.start("SRAQE")
    state = Dordle.process_guess(Dordle.get_state(), "RAQES")

    assert state ==
             %State{
               game_over: false,
               word: ~c"SRAQE",
               num_guessed: 1,
               guesses: [[guess: "RAQES", exact_locs: [], other_locs: [1, 2, 3, 4, 5]]]
             }
  end

  test "process_guess 2 exact, 2 other" do
    Dordle.start("SRAQE")
    state = Dordle.process_guess(Dordle.get_state(), "SAZQR")

    assert state ==
             %State{
               game_over: false,
               word: ~c"SRAQE",
               num_guessed: 1,
               guesses: [[guess: "SAZQR", exact_locs: [1, 4], other_locs: [2, 5]]]
             }
  end

  test "process_guess 2 exact, 3 other" do
    Dordle.start("ABCDE")
    state = Dordle.process_guess(Dordle.get_state(), "CBEDA")

    assert state ==
             %State{
               game_over: false,
               word: ~c"ABCDE",
               num_guessed: 1,
               guesses: [[guess: "CBEDA", exact_locs: [2, 4], other_locs: [1, 3, 5]]]
             }
  end

  test "process_guess to completion" do
    Dordle.start("MNOPQ")

    state =
      Dordle.process_guess(Dordle.get_state(), "AAAAA")
      |> Dordle.process_guess("BBBBB")
      |> Dordle.process_guess("CCCCC")
      |> Dordle.process_guess("DDDDD")
      |> Dordle.process_guess("EEEEE")
      |> Dordle.process_guess("FFFFF")

    assert state ==
             %State{
               game_over: true,
               word: ~c"MNOPQ",
               num_guessed: 6,
               guesses: [
                 [guess: "AAAAA", exact_locs: [], other_locs: []],
                 [guess: "BBBBB", exact_locs: [], other_locs: []],
                 [guess: "CCCCC", exact_locs: [], other_locs: []],
                 [guess: "DDDDD", exact_locs: [], other_locs: []],
                 [guess: "EEEEE", exact_locs: [], other_locs: []],
                 [guess: "FFFFF", exact_locs: [], other_locs: []]
               ]
             }
  end

  #

  test "process_guess CREST 4/14/25" do
    Dordle.start("CREST")

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ARISE", exact_locs: [2, 4], other_locs: [5]]]
             },
             Dordle.process_guess(Dordle.get_state(), "ARISE")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "FRESH", exact_locs: [2, 3, 4], other_locs: []]]
             },
             Dordle.process_guess(Dordle.get_state(), "FRESH")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "WREST", exact_locs: [2, 3, 4, 5], other_locs: []]]
             },
             Dordle.process_guess(Dordle.get_state(), "WREST")
           )

    assert match?(
             %State{
               game_over: true,
               guesses: [[guess: "CREST", exact_locs: [1, 2, 3, 4, 5], other_locs: []]]
             },
             Dordle.process_guess(Dordle.get_state(), "CREST")
           )
  end

  test "process_guess LAUGH 4/13/25" do
    Dordle.start("LAUGH")

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ARISE", exact_locs: [], other_locs: [1]]]
             },
             Dordle.process_guess(Dordle.get_state(), "ARISE")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "CHANT", exact_locs: [], other_locs: [2, 3]]]
             },
             Dordle.process_guess(Dordle.get_state(), "CHANT")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "GAUCH", exact_locs: [2, 3, 5], other_locs: [1]]]
             },
             Dordle.process_guess(Dordle.get_state(), "GAUCH")
           )

    assert match?(
             %State{
               game_over: true,
               guesses: [[guess: "LAUGH", exact_locs: [1, 2, 3, 4, 5], other_locs: []]]
             },
             Dordle.process_guess(Dordle.get_state(), "LAUGH")
           )
  end

  test "process_guess NURSE 4/12/25" do
    Dordle.start("NURSE")

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ARISE", exact_locs: [4, 5], other_locs: [2]]]
             },
             Dordle.process_guess(Dordle.get_state(), "ARISE")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ROUSE", exact_locs: [4, 5], other_locs: [1, 3]]]
             },
             Dordle.process_guess(Dordle.get_state(), "ROUSE")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "PURSE", exact_locs: [2, 3, 4, 5], other_locs: []]]
             },
             Dordle.process_guess(Dordle.get_state(), "PURSE")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "CURSE", exact_locs: [2, 3, 4, 5], other_locs: []]]
             },
             Dordle.process_guess(Dordle.get_state(), "CURSE")
           )

    assert match?(
             %State{
               game_over: true,
               guesses: [[guess: "NURSE", exact_locs: [1, 2, 3, 4, 5], other_locs: []]]
             },
             Dordle.process_guess(Dordle.get_state(), "NURSE")
           )
  end

  test "process_guess ARROW 4/11/25" do
    Dordle.start("ARROW")

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ARISE", exact_locs: [1, 2], other_locs: []]]
             },
             Dordle.process_guess(Dordle.get_state(), "ARISE")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ARMOR", exact_locs: [1, 2, 4], other_locs: [5]]]
             },
             Dordle.process_guess(Dordle.get_state(), "ARMOR")
           )

    assert match?(
             %State{
               game_over: true,
               guesses: [[guess: "ARROW", exact_locs: [1, 2, 3, 4, 5], other_locs: []]]
             },
             Dordle.process_guess(Dordle.get_state(), "ARROW")
           )
  end

  test "process_guess TURBO 4/10/25" do
    Dordle.start("TURBO")

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ARISE", exact_locs: [], other_locs: [2]]]
             },
             Dordle.process_guess(Dordle.get_state(), "ARISE")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [
                 #  [guess: "ARISE", exact_locs: [], other_locs: [2]],
                 [guess: "ROUND", exact_locs: [], other_locs: [1, 2, 3]]
               ]
             },
             Dordle.process_guess(Dordle.get_state(), "ROUND")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "FLOUR", exact_locs: [], other_locs: [3, 4, 5]]]
             },
             Dordle.process_guess(Dordle.get_state(), "FLOUR")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "CURIO", exact_locs: [2, 3, 5], other_locs: []]]
             },
             Dordle.process_guess(Dordle.get_state(), "CURIO")
           )

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "BURRO", exact_locs: [2, 3, 5], other_locs: [1]]]
             },
             Dordle.process_guess(Dordle.get_state(), "BURRO")
           )

    assert match?(
             %State{
               game_over: true,
               guesses: [[guess: "TURBO", exact_locs: [1, 2, 3, 4, 5], other_locs: []]]
             },
             Dordle.process_guess(Dordle.get_state(), "TURBO")
           )
  end

  ##########

  test "process_guess with state SHEAR 4/3/25" do
    Dordle.start("SHEAR")

    #
    state = Dordle.process_guess(Dordle.get_state(), "ARISE")

    assert match?(
             %State{
               game_over: false,
               guesses: [[guess: "ARISE", exact_locs: [], other_locs: [1, 2, 4, 5]]]
             },
             state
           )

    #
    state = Dordle.process_guess(state, "STARE")

    assert match?(
             %State{
               game_over: false,
               guesses: [
                 [guess: "ARISE", exact_locs: [], other_locs: [1, 2, 4, 5]],
                 [guess: "STARE", exact_locs: [1], other_locs: [3, 4, 5]]
               ]
             },
             state
           )

    #
    state = Dordle.process_guess(state, "SAFER")

    assert match?(
             %State{
               game_over: false,
               guesses: [
                 [guess: "ARISE", exact_locs: [], other_locs: [1, 2, 4, 5]],
                 [guess: "STARE", exact_locs: [1], other_locs: [3, 4, 5]],
                 [guess: "SAFER", exact_locs: [1, 5], other_locs: [2, 4]]
               ]
             },
             state
           )

    #
    state = Dordle.process_guess(state, "SEWAR")

    assert match?(
             %State{
               game_over: false,
               guesses: [
                 [guess: "ARISE", exact_locs: [], other_locs: [1, 2, 4, 5]],
                 [guess: "STARE", exact_locs: [1], other_locs: [3, 4, 5]],
                 [guess: "SAFER", exact_locs: [1, 5], other_locs: [2, 4]],
                 [guess: "SEWAR", exact_locs: [1, 4, 5], other_locs: [2]]
               ]
             },
             state
           )

    #
    state = Dordle.process_guess(state, "SPEAR")

    assert match?(
             %State{
               game_over: false,
               guesses: [
                 [guess: "ARISE", exact_locs: [], other_locs: [1, 2, 4, 5]],
                 [guess: "STARE", exact_locs: [1], other_locs: [3, 4, 5]],
                 [guess: "SAFER", exact_locs: [1, 5], other_locs: [2, 4]],
                 [guess: "SEWAR", exact_locs: [1, 4, 5], other_locs: [2]],
                 [guess: "SPEAR", exact_locs: [1, 3, 4, 5], other_locs: []]
               ]
             },
             state
           )

    #
    state = Dordle.process_guess(state, "SHEAR")

    assert match?(
             %State{
               game_over: true,
               guesses: [
                 [guess: "ARISE", exact_locs: [], other_locs: [1, 2, 4, 5]],
                 [guess: "STARE", exact_locs: [1], other_locs: [3, 4, 5]],
                 [guess: "SAFER", exact_locs: [1, 5], other_locs: [2, 4]],
                 [guess: "SEWAR", exact_locs: [1, 4, 5], other_locs: [2]],
                 [guess: "SPEAR", exact_locs: [1, 3, 4, 5], other_locs: []],
                 [guess: "SHEAR", exact_locs: [1, 2, 3, 4, 5], other_locs: []]
               ]
             },
             state
           )
  end

  ###

  @tag :skip
  test "output" do
    guesses = [
      [guess: "ARISE", exact_locs: [], other_locs: [1, 2, 4, 5]],
      [guess: "STARE", exact_locs: [1], other_locs: [3, 4, 5]],
      [guess: "SAFER", exact_locs: [1, 5], other_locs: [2, 4]],
      [guess: "SEWAR", exact_locs: [1, 4, 5], other_locs: [2]],
      [guess: "SPEAR", exact_locs: [1, 3, 4, 5], other_locs: []],
      [guess: "SHEAR", exact_locs: [1, 2, 3, 4, 5], other_locs: []]
    ]

    Dordle.output(guesses)
  end

  #

  test "guess" do
    Dordle.start("SHEAR")

    Dordle.guess("ARISE")
    IO.puts("")

    Dordle.guess("STARE")
    IO.puts("")

    Dordle.guess("SAFER")
    IO.puts("")

    Dordle.guess("SEWAR")
    IO.puts("")

    Dordle.guess("SPEAR")
    IO.puts("")

    Dordle.guess("SHEAR")

    IO.inspect(Dordle.get_state(), label: "Final State")
  end
end
