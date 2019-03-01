# frozen_string_literal: true

require_relative "../support/test_classes/bottle"
require_relative "../support/test_classes/count_out_current_bottles"
require_relative "../support/test_classes/pass_bottles_around"
require_relative "../support/test_classes/take_bottles_down"
require_relative "../support/test_classes/bottles_on_the_wall_state"
require_relative "../support/test_classes/bottles_on_the_wall_flow"

RSpec.describe Flow, type: :integration do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    ActiveRecord::Base.connection.create_table :bottles do |t|
      t.string :of, unique: true
      t.integer :number_on_the_wall, default: 99
      t.integer :number_passed_around, default: 0
    end
  end

  after(:all) { ActiveRecord::Base.connection.drop_table :bottles } # rubocop:disable RSpec/BeforeAfterAll

  after { Bottle.destroy_all }

  subject(:flow) { BottlesOnTheWallFlow.trigger(**input) }

  let(:bottles_of) { "beer" }
  let(:number_to_take_down) { nil }
  let(:starting_bottles) { nil }
  let(:output) { nil }
  let(:input) do
    {
      bottles_of: bottles_of,
      starting_bottles: starting_bottles,
      number_to_take_down: number_to_take_down,
      output: output,
    }.compact
  end

  shared_examples_for "a successful flow" do
    it { is_expected.to be_an_instance_of BottlesOnTheWallFlow }
    it { is_expected.to be_state_valid }
    it { is_expected.not_to be_pending }
    it { is_expected.to be_triggered }
    it { is_expected.to be_success }
    it { is_expected.not_to be_failed }
    it { is_expected.not_to be_reverted }
  end

  shared_examples_for "a failed flow" do
    it { is_expected.to be_an_instance_of BottlesOnTheWallFlow }

    it { is_expected.to be_state_valid }
    it { is_expected.not_to be_pending }
    it { is_expected.to be_triggered }
    it { is_expected.not_to be_success }
    it { is_expected.to be_failed }
    it { is_expected.to be_reverted }
    it { is_expected.to be_failed_operation }

    it "has a failed operation" do
      expect(flow.failed_operation.operation_failure).to be_an_instance_of Operation::Failures::OperationFailure
      expect(flow.failed_operation).to be_executed
      expect(flow.failed_operation).not_to be_success
    end
  end

  context "without bottles_of" do
    let(:bottles_of) { nil }

    it "raises" do
      expect { flow }.to raise_error ArgumentError, "Missing argument: bottles_of"
    end
  end

  context "with defaults" do
    let(:expected_string) { raw_string.delete("\n") }
    let(:raw_string) do
      <<~STRING.chomp
        #<BottlesOnTheWallState
         bottles_of="beer"
         starting_bottles=nil
         number_to_take_down=1
         output=[
        "99 bottles of beer on the wall, 99 bottles of beer.",
         "You take one down.",
         "You pass it around.",
         "98 bottles of beer on the wall."
        ]
        >
      STRING
    end

    it_behaves_like "a successful flow"

    it "produces expected stanza" do
      expect(flow.state.stanza).to eq <<~STANZA.chomp
        99 bottles of beer on the wall, 99 bottles of beer.
        You take one down.
        You pass it around.
        98 bottles of beer on the wall.
      STANZA
    end

    describe "#state#to_s" do
      subject { flow.state.to_s }

      let(:raw_string) do
        <<~STRING.chomp
          #<BottlesOnTheWallState
           bottles_of=beer
           starting_bottles=
           number_to_take_down=1
           output=[
          "99 bottles of beer on the wall, 99 bottles of beer.",
           "You take one down.",
           "You pass it around.",
           "98 bottles of beer on the wall."
          ]
          >
        STRING
      end

      it { is_expected.to eq expected_string }
    end

    describe "#state#inspect" do
      subject { flow.state.inspect }

      let(:raw_string) do
        <<~STRING.chomp
          #<BottlesOnTheWallState
           bottles_of="beer"
           starting_bottles=nil
           number_to_take_down=1
           output=[
          "99 bottles of beer on the wall, 99 bottles of beer.",
           "You take one down.",
           "You pass it around.",
           "98 bottles of beer on the wall."
          ]
          >
        STRING
      end

      it { is_expected.to eq expected_string }
    end
  end

  context "with starting_bottles" do
    context "when invalid" do
      let(:starting_bottles) { -1 }

      it "raises" do
        expect { flow }.to raise_error ActiveRecord::RecordInvalid,
                                       "Validation failed: Number on the wall must be greater than or equal to 0"
      end
    end

    context "when one" do
      let(:starting_bottles) { 1 }

      it_behaves_like "a successful flow"

      it "produces expected stanza" do
        expect(flow.state.stanza).to eq <<~STANZA.chomp
          1 bottle of beer on the wall, 1 bottle of beer.
          You take it down.
          You pass it around.
          No more bottles of beer on the wall.
        STANZA
      end
    end

    context "when one million" do
      let(:starting_bottles) { 1_000_000 }

      it_behaves_like "a successful flow"

      it "produces expected stanza" do
        expect(flow.state.stanza).to eq <<~STANZA.chomp
          1000000 bottles of beer on the wall, 1000000 bottles of beer.
          You take one down.
          You pass it around.
          999999 bottles of beer on the wall.
        STANZA
      end
    end
  end

  context "with number_to_take_down" do
    context "when invalid" do
      let(:number_to_take_down) { -1 }

      it "does not run" do
        expect { flow }.not_to change { Bottle.count }
      end

      it { is_expected.not_to be_state_valid }
      it { is_expected.to be_pending }
      it { is_expected.not_to be_triggered }
      it { is_expected.not_to be_success }
      it { is_expected.not_to be_failed }
      it { is_expected.not_to be_reverted }

      context "with trigger!" do
        subject(:trigger!) { BottlesOnTheWallFlow.trigger!(**input) }

        it "raises" do
          expect { trigger! }.to raise_error Flow::Errors::StateInvalid
        end
      end
    end

    context "when none" do
      let(:number_to_take_down) { 0 }

      it_behaves_like "a successful flow"

      it "produces expected stanza" do
        expect(flow.state.stanza).to eq <<~STANZA.chomp
          99 bottles of beer on the wall, 99 bottles of beer.
          You took nothing down.
          You pass nothing around.
          99 bottles of beer on the wall.
        STANZA
      end
    end

    context "when many" do
      let(:number_to_take_down) { 3 }

      it_behaves_like "a successful flow"

      it "produces expected stanza" do
        expect(flow.state.stanza).to eq <<~STANZA.chomp
          99 bottles of beer on the wall, 99 bottles of beer.
          You take 3 down.
          You pass them around.
          96 bottles of beer on the wall.
        STANZA
      end
    end

    context "when one million" do
      let(:starting_bottles) { 1_000_000 }

      it_behaves_like "a successful flow"

      it "produces expected stanza" do
        expect(flow.state.stanza).to eq <<~STANZA.chomp
          1000000 bottles of beer on the wall, 1000000 bottles of beer.
          You take one down.
          You pass it around.
          999999 bottles of beer on the wall.
        STANZA
      end
    end
  end

  context "when number_to_take_down is greater than starting_bottles" do
    let(:starting_bottles) { 2 }
    let(:number_to_take_down) { 3 }

    it "raises" do
      expect { flow }.to raise_error ActiveRecord::RecordInvalid,
                                     "Validation failed: Number on the wall must be greater than or equal to 0"
    end
  end

  context "when the second operation fails by a known error" do
    let(:bottles) { Bottle.create(of: bottles_of, number_on_the_wall: starting_bottles) }
    let(:starting_bottles) { 4 }
    let(:number_to_take_down) { 3 }

    before { bottles.update!(number_passed_around: 99) }

    it_behaves_like "a failed flow"

    it "has a failed operation" do
      expect(flow.failed_operation).to be_an_instance_of PassBottlesAround
      expect(flow.failed_operation.operation_failure.problem).to eq :record_invalid
    end

    it "produces expected stanza" do
      expect(flow.state.stanza).to eq <<~STANZA.chomp
        4 bottles of beer on the wall, 4 bottles of beer.
        You take 3 down.
        Passing the bottles wasn't as sound, now there's 3 on the ground!
      STANZA
    end
  end

  context "when the second operation fails" do
    let(:number_to_take_down) { 5 }

    it_behaves_like "a failed flow"

    it "has a failed operation" do
      expect(flow.failed_operation).to be_an_instance_of TakeBottlesDown
      expect(flow.failed_operation.operation_failure.problem).to eq :too_greedy
    end

    it "produces expected stanza" do
      expect(flow.state.stanza).to eq <<~STANZA.chomp
        99 bottles of beer on the wall, 99 bottles of beer.
        Something went wrong! It's the end of the song, and there's 99 bottles of beer on the wall.
      STANZA
    end
  end

  context "when the third operation fails" do
    let(:number_to_take_down) { 4 }

    it_behaves_like "a failed flow"

    it "has a failed operation" do
      expect(flow.failed_operation).to be_an_instance_of PassBottlesAround
      expect(flow.failed_operation.operation_failure.problem).to eq :too_generous
    end

    it "produces expected stanza" do
      expect(flow.state.stanza).to eq <<~STANZA.chomp
        99 bottles of beer on the wall, 99 bottles of beer.
        You take 4 down.
      STANZA
    end
  end
end
