# frozen_string_literal: true

require 'rouge'

module Rouge
  module Themes
    class RubyLLMLight < CSSTheme
      name 'rubyllm.light'

      palette bg: '#faf9f7',
              fg: '#2c2926',
              comment: '#928374',
              red: '#9d0006',
              orange: '#af3a03',
              purple: '#8f3f71',
              yellow: '#b57614',
              aqua: '#427b58',
              green: '#79740e',
              blue: '#076678',
              diff_bg: '#fbf1c7'

      style Text, fg: :fg, bg: :bg
      style Error, fg: :red, bg: :diff_bg, bold: true
      style Comment, fg: :comment, italic: true
      style Comment::Preproc, fg: :aqua
      style Operator, Punctuation, fg: :fg
      style Generic::Inserted, fg: :green, bg: :diff_bg
      style Generic::Deleted, fg: :red, bg: :diff_bg
      style Generic::Heading, fg: :aqua, bold: true
      style Generic::Emph, italic: true
      style Generic::EmphStrong, italic: true, bold: true
      style Generic::Strong, bold: true
      style Keyword, fg: :red
      style Keyword::Constant, fg: :purple
      style Keyword::Declaration, fg: :orange
      style Keyword::Type, fg: :yellow
      style Literal::Number, Name::Constant, fg: :purple
      style Literal::String, Literal::String::Interpol, Literal::String::Regex, fg: :green, italic: true
      style Literal::String::Affix, Name::Tag, fg: :red
      style Literal::String::Escape, fg: :orange
      style Literal::String::Symbol, fg: :blue
      style Name::Class, Name::Namespace, Comment::Special, fg: :aqua
      style Name::Attribute, fg: :green
      style Name, Name::Builtin, Name::Function, Name::Exception, Name::Label,
            Name::Property, Name::Decorator, Name::Variable, Name::Variable::Class,
            Name::Variable::Global, Name::Variable::Instance, Name::Variable::Magic, fg: :fg
    end

    class RubyLLMDark < CSSTheme
      name 'rubyllm.dark'

      palette bg: '#191919',
              fg: '#ebe8dc',
              comment: '#928374',
              red: '#fb4934',
              orange: '#fe8019',
              purple: '#d3869b',
              yellow: '#fabd2f',
              aqua: '#8ec07c',
              green: '#b8bb26',
              blue: '#83a598',
              diff_bg: '#282828'

      style Text, fg: :fg, bg: :bg
      style Error, fg: :red, bg: :diff_bg, bold: true
      style Comment, fg: :comment, italic: true
      style Comment::Preproc, fg: :aqua
      style Operator, Punctuation, fg: :fg
      style Generic::Inserted, fg: :green, bg: :diff_bg
      style Generic::Deleted, fg: :red, bg: :diff_bg
      style Generic::Heading, fg: :aqua, bold: true
      style Generic::Emph, italic: true
      style Generic::EmphStrong, italic: true, bold: true
      style Generic::Strong, bold: true
      style Keyword, fg: :red
      style Keyword::Constant, fg: :purple
      style Keyword::Declaration, fg: :orange
      style Keyword::Type, fg: :yellow
      style Literal::Number, Name::Constant, fg: :purple
      style Literal::String, Literal::String::Interpol, Literal::String::Regex, fg: :green, italic: true
      style Literal::String::Affix, Name::Tag, fg: :red
      style Literal::String::Escape, fg: :orange
      style Literal::String::Symbol, fg: :blue
      style Name::Class, Name::Namespace, Comment::Special, fg: :aqua
      style Name::Attribute, fg: :green
      style Name, Name::Builtin, Name::Function, Name::Exception, Name::Label,
            Name::Property, Name::Decorator, Name::Variable, Name::Variable::Class,
            Name::Variable::Global, Name::Variable::Instance, Name::Variable::Magic, fg: :fg
    end
  end
end
