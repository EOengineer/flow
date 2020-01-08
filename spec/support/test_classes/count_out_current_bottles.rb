# frozen_string_literal: true

class CountOutCurrentBottles < Flow::OperationBase
  state_reader :stanza
  state_reader :bottles

  def behavior
    stanza.push "#{bottles} on the wall#{", #{bottles}" if stanza.empty?}."
  end
end
