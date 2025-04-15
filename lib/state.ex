defmodule State do
  # TODO: rot13 the word
  defstruct game_over: false, word: nil, num_guessed: 0, guesses: []
end
