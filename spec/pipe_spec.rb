require 'spec_helper'

# Parent is a dummy test class.
class Parent < Pipes::Pipe
  require_context :flow

  def call
    flow.push(self.class.name)
  end
end # class Parent

class Child < Parent; end
class Grandchild < Parent; end
class GrandGrandchild < Parent; end

# BadApple will break.
class BadApple < Pipes::Pipe
  def call
    fail StandardError
  end
end

# NoMethodPipe will break with NoMethodError.
class NoMethodPipe < Pipes::Pipe; end

describe Pipes::Pipe do
  let(:ctx) { Pipes::Context.new(flow: []) }

  subject { pipe.call(ctx) }

  describe 'normal flow' do
    let(:pipe) { Parent | Child | Grandchild }

    it 'executes the pipe left to right' do
      expect { subject }.to change { ctx.flow }
        .from([]).to %w(Parent Child Grandchild)
    end
  end # describe 'normal flow'

  describe 'pipe raising an exception' do
    let(:pipe) { Parent | BadApple | Child }

    it 'raises StandardError' do
      expect { pipe.call(ctx) }.to raise_error StandardError
    end

    it 'stores the result of execution so far in the context' do
      # rubocop:disable Style/RescueModifier
      expect { pipe.call(ctx) rescue nil }
        .to change { ctx.flow }
        .from([]).to(['Parent'])
      # rubocop:enable Style/RescueModifier
    end
  end # describe 'pipe raising an exception'

  describe '.provide_context' do
    context 'when context element provided' do
      class ProvidingChild < Parent
        provide_context :bacon

        def call
          super
          add(bacon: true)
        end
      end # class ProvideChild

      let(:pipe) { Parent | ProvidingChild }

      it 'does not raise' do
        expect { subject }.to_not raise_error
      end
    end # context 'when context element provided'

    context 'when context element not provided' do
      class NotProvidingChild < Parent
        provide_context :bacon
      end

      let(:pipe) { Parent | NotProvidingChild }

      it 'raises MissingContext' do
        expect { subject }.to raise_error Pipes::MissingContext
      end
    end # context 'when context element not provided'
  end # describe '.provide_context'

  describe 'pipes declared using Pipe::Closure' do
    let(:dynamic_grandchild) do
      Pipes::Closure.define { context.flow << 'bacon' }
    end
    let(:pipe) { Parent | dynamic_grandchild | Child }

    it 'behaves as with normal pipes' do
      expect { subject }
        .to change { ctx.flow }
        .from([]).to %w(Parent bacon Child)
    end
  end # describe 'pipes declared using Pipe::Closure'

  describe 'pipe with a missing `call` method' do
    let(:pipe) { Parent | Child | NoMethodPipe }

    it 'raises a Pipes::MissingCallMethod error' do
      expect { subject }.to raise_error Pipes::MissingCallMethod
    end
  end # describe 'pipe with a missing `call` method'

  describe 'combined pipes' do
    let(:first)  { Parent | Child }
    let(:second) { Grandchild | GrandGrandchild }
    let(:pipe)   { first | second }

    it 'behaves as with normal pipes' do
      expect { subject }
        .to change { ctx.flow }
        .from([]).to %w(Parent Child Grandchild GrandGrandchild)
    end

    describe 'broken combination' do
      let(:second) { NoMethodPipe | Grandchild }

      it 'raises error from a broken pipe' do
        expect { subject }.to raise_error Pipes::MissingCallMethod
      end
    end # describe 'broken combination'
  end # describe 'combined pipes'
end # describe Pipes::Pipe
