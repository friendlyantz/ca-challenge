# frozen_string_literal: true

RSpec.describe Loaders::UiInterfaceErrors do
  include Dry::Monads[:result]

  subject(:error_handling) { described_class.call(output:) { result } }

  let(:output) { StringIO.new }

  context 'when result return a Success' do
    let(:result) { Success() }

    it 'returns an :ok' do
      expect(error_handling).to eq :ok
    end

    it 'does NOT puts anything to output' do
      expect { error_handling }.not_to(change(output, :string))
    end
  end

  context 'when result return a Failure(:exit)' do
    let(:result) { Failure(:exit) }

    it 'returns an :ok' do
      expect(error_handling).to eq :ok
    end

    it 'calls puts on the output with "exiting.. Goodbye"' do
      expect { error_handling }.to change(output, :string).from('').to("exiting.. Goodbye\n")
    end
  end

  context 'when result return a Failure(Errno::ENOENT)' do
    let(:result) { Failure(Errno::ENOENT.new) }

    it 'returns an :error' do
      expect(error_handling).to eq :error
    end

    it 'calls puts on the output error message' do
      expect { error_handling }.to change(output, :string)
        .from('')
        .to("Sorry, unable to load the provided input data\nPlease ensure the input data file path is correct.\n")
    end
  end

  context 'when result return a Failure(Errors::GenerateDatabase)' do
    let(:result) { Failure(Errors::GenerateDatabase.new('SOME_ERROR!')) }

    it 'returns an :error' do
      expect(error_handling).to eq :error
    end

    it 'calls puts on the output error message' do
      expect { error_handling }.to change(output, :string)
        .from('')
        .to("Sorry, there seems to be an issue in loading the application.\nReason: SOME_ERROR!\n")
    end
  end

  context 'when result return a Failure with other message' do
    let(:result) { Failure(:error) }

    it 'returns an :error' do
      expect(error_handling).to eq :error
    end

    it 'calls puts on the output with "Oops, this is embarassing, some unexpected error has occured."' do
      expect { error_handling }
        .to change(output, :string)
        .from('').to("Oops, this is embarassing, some unexpected error has occured.\n")
    end
  end

  context 'when result raises and unexpected exception' do
    let(:result) { raise('SOME_ERROR!') }

    it 'returns an :error' do
      expect(error_handling).to eq :error
    end

    it 'calls puts on the output with "Oops, this is embarassing, some unexpected error has occured."' do
      expect { error_handling }
        .to change(output, :string)
        .from('').to("Oops, this is embarassing, some unexpected error has occured.\n")
    end
  end
end
