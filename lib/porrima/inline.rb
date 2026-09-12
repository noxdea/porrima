# frozen_string_literal: true

module Porrima
  module Inline
    TOKEN_LIMIT = 2_000
    module_function

    def refine(old_text, new_text, granularity: :word)
      old_tokens = tokenize(old_text, granularity)
      new_tokens = tokenize(new_text, granularity)
      return replacement(old_text, new_text) if old_tokens.length + new_tokens.length > TOKEN_LIMIT
      changes = Porrima.edits(old_tokens, new_tokens)
      [spans(changes.reject { |edit| edit.kind == :insert }), spans(changes.reject { |edit| edit.kind == :delete })]
    end

    def refine_row(row, granularity: :word)
      refine(row.old_text.to_s, row.new_text.to_s, granularity: granularity)
    end

    def tokenize(text, granularity)
      case granularity
      when :word then text.scan(/\w+|\s+|./)
      when :char then text.grapheme_clusters
      else raise ArgumentError, "granularity must be :word or :char"
      end
    end
    private_class_method :tokenize

    def spans(edits)
      edits.each_with_object([]) do |edit, result|
        if result.last&.kind == edit.kind
          result.last.text << edit.text
        else
          result << Span.new(kind: edit.kind, text: edit.text.dup)
        end
      end
    end
    private_class_method :spans

    def replacement(old_text, new_text)
      [old_text.empty? ? [] : [Span.new(kind: :delete, text: old_text)],
       new_text.empty? ? [] : [Span.new(kind: :insert, text: new_text)]]
    end
    private_class_method :replacement
  end
end
