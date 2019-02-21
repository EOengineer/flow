# frozen_string_literal: true

RSpec.describe Operation::Callbacks, type: :module do
  subject(:example_class) { Class.new.include described_class }

  it_behaves_like "an example class with callbacks", described_class, :failure

  describe "#on_failure" do
    subject(:failure) { instance.run_callbacks(:failure) }

    let(:instance) { test_class.new }
    let(:test_class) do
      Class.new(example_class) do
        attr_accessor :before_hook_run

        on_failure { self.before_hook_run = true }
      end
    end

    it "runs callback on failure" do
      expect { failure }.to change { instance.before_hook_run }.from(nil).to(true)
    end
  end
end
