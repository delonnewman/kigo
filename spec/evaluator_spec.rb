require 'spec_helper'

class SelfEvaluatingForm < SimpleGenerator
  def initialize
    @forms = [String, Integer, Float, true, false, nil]
  end

  def generate
    @forms.sample.generate
  end
end

RSpec.describe Kigo::Evaluator do
  let(:evaluator) { Kigo::Evaluator.new }

  context '#evaluate' do
    context 'self-evaluating forms' do
      for_all SelfEvaluatingForm do |form|
        it "should return #{form.inspect} unevaluated" do
          expect(evaluator.evaluate(form)).to eq form
        end
      end
    end

    context 'keyword' do
      # TODO: this should probably change
      it 'should return the symbol it encapsulates' do
        expect(evaluator.evaluate(Kigo::Keyword.new(:test))).to eq :test
      end
    end

    context 'collections' do
      it 'should return a set with the values evaluated' do
        evaluator.env.define(:x, 1)
        expect(evaluator.evaluate(Set[:x, 2, 3, 4])).to eq Set[1, 2, 3, 4]
      end

      it 'should return a hash with the keys and values evaluated' do
        evaluator.env.define(:name, "James")
        expect(evaluator.evaluate({ name: :name })).to eq({ "James" => "James" })
      end

      it 'should return an array with the values evaluated' do
        evaluator.env.define(:x, 1)
        expect(evaluator.evaluate([:x, 2, 3, 4])).to eq [1, 2, 3, 4]
      end
    end

    context '(quote x)' do
      it 'should return the value it quotes unevaluated' do
        expect(evaluator.evaluate(Kigo::Cons[:quote, [:x, 1, 2, 3]])).to eq [:x, 1, 2, 3]
        expect(evaluator.evaluate(Kigo::Cons[:quote, Kigo::Cons[:quote, 1]])).to eq Kigo::Cons[:quote, 1]
      end
    end

    context '(def x y)' do
      it 'should define the symbol in the current environment' do
        evaluator.evaluate(Kigo::Cons[:def, :z, 3])
        expect(evaluator.evaluate(:z)).to eq 3
      end
    end

    context '(set! x y)' do
      it 'should assign a new value to the given symbol' do
        evaluator.evaluate(Kigo::Cons[:def, :name, "Jane"])
        expect(evaluator.evaluate(:name)).to eq "Jane"
        evaluator.evaluate(Kigo::Cons[:set!, :name, "John"])
        expect(evaluator.evaluate(:name)).to eq "John"
      end
    end

    context '(lambda (*args) *body)' do
      it 'should accept arguments and evaluate the body when called' do
        ident = Kigo::Cons[:lambda, Kigo::Cons[:value], :value]
        expect(evaluator.evaluate(ident).call(1)).to eq 1
        expect { evaluator.evaluate(:value) }.to raise_error Kigo::RuntimeError
      end
    end

    context '(macro (*args) *body)' do
      let(:macro) {
        Kigo::Cons[:macro,
          Kigo::Cons[:pred, :conse, :alt],
          Kigo::Cons[:'Kigo::Cons', Kigo::Cons[:quote, :cond], :pred, :conse, Kigo::Cons[:quote, :else], :alt]]
      }

      let(:definition) { Kigo::Cons[:def, :if, macro] }

      it 'should accept arguments and evalute the body when expanded' do
        expect(evaluator.evaluate(macro)).to be_a Kigo::Macro
        expect(evaluator.evaluate(macro).call(nil, nil, true, 1, 2)).to eq Kigo::Cons[:cond, true, 1, :else, 2]
      
        #evaluator.evaluate(definition)
        evaluator.env.define(:if, evaluator.evaluate(macro))
        #expect(evaluator.evaluate(:if)).to be_a Kigo::Macro
        expect(evaluator.macroexpand1(Kigo::Cons[:if, true, 1, 2])).to eq Kigo::Cons[:cond, true, 1, :else, 2]
        expect(evaluator.evaluate(Kigo::Cons[:if, true, 1, 2])).to eq 1
      end
    end

    context '(cond *predicate-consequent-pairs)' do
      it 'should evaluate to the value if the first pair whose predicate is truthy or :else' do
        examples = [
          { form: Kigo::Cons[:cond, true, 1, true, 2, :else, 3], value: 1 },
          { form: Kigo::Cons[:cond, false, 1, true, 2, :else, 3], value: 2 },
          { form: Kigo::Cons[:cond, false, 1, nil, 2, :else, 3], value: 3 },
          { form: Kigo::Cons[:cond, false, 1, nil, 2, false, 3], value: nil }
        ]

        examples.each do |example|
          expect(evaluator.evaluate(example[:form])).to eq example[:value]
        end
      end
    end

    context '(send object method *args)' do
      it 'should send method with (optional) arguments to object' do
        examples = [
          { form: Kigo::Cons[:send, 1, Kigo::Keyword.new(:to_s)], value: "1" },
          { form: Kigo::Cons[:send, 1, Kigo::Keyword.new(:+), 2], value: 3 }
        ]

        examples.each do |example|
          expect(evaluator.evaluate(example[:form])).to eq example[:value]
        end
      end
    end
  end
end