module Gemnasium
  module Parser
    module Patterns
      GEM_NAME = /[a-zA-Z0-9\-_\.]+/
      QUOTED_GEM_NAME = /(?:(?<gq>["'])(?<name>#{GEM_NAME})\k<gq>|%q<(?<name>#{GEM_NAME})>)/

      MATCHER = /(?:=|!=|>|<|>=|<=|~>)/
      VERSION = /[0-9]+(?:\.[a-zA-Z0-9]+)*/
      REQUIREMENT = /[ \t]*(?:#{MATCHER}[ \t]*)?#{VERSION}[ \t]*/
      REQUIREMENT_LIST = /(?<qr1>["'])(?<req1>#{REQUIREMENT})\k<qr1>(?:[ \t]*,[ \t]*(?<qr2>["'])(?<req2>#{REQUIREMENT})\k<qr2>)?/
      REQUIREMENTS = /(?:#{REQUIREMENT_LIST}|\[[ \t]*#{REQUIREMENT_LIST}[ \t]*\])/

      KEY = /(?::\w+|:?"\w+"|:?'\w+')/
      SYMBOL = /(?::\w+|:"[^"#]+"|:'[^']+')/
      STRING = /(?:"[^"#]*"|'[^']*')/
      BOOLEAN = /(?:true|false)/
      NIL = /nil/
      ELEMENT = /(?:#{SYMBOL}|#{STRING})/
      ARRAY = /\[(?:#{ELEMENT}(?:[ \t]*,[ \t]*#{ELEMENT})*)?\]/
      VALUE = /(?:#{BOOLEAN}|#{NIL}|#{ELEMENT}|#{ARRAY}|)/
      PAIR = /(?:(#{KEY})[ \t]*=>[ \t]*(#{VALUE})|(\w+):[ \t]+(#{VALUE}))/
      OPTIONS = /#{PAIR}(?:[ \t]*,[ \t]*#{PAIR})*/

      GEM_CALL = /^[ \t]*gem\(?[ \t]*(?<qname>#{QUOTED_GEM_NAME})(?:[ \t]*,[ \t]*(?<reqall>(?<rso>\[)?[ \t]*#{REQUIREMENT_LIST}(?<rsc>\])?))?(?:[ \t]*,[ \t]*(?<opts>#{OPTIONS}))?.*$/

      SYMBOLS = /#{SYMBOL}([ \t]*,[ \t]*#{SYMBOL})*/
      GROUP_CALL = /^(?<i1>[ \t]*)group\(?[ \t]*(?<grps>#{SYMBOLS})[ \t]*\)?[ \t]+do[ \t]*?\n(?<blk>.*?)\n^\k<i1>end[ \t]*$/m

      GIT_CALL = /^(?<i1>[ \t]*)git[ \(][^\n]*?do[ \t]*?\n(?<blk>.*?)\n^\k<i1>end[ \t]*$/m

      PATH_CALL = /^(?<i1>[ \t]*)path[ \(][^\n]*?do[ \t]*?\n(?<blk>.*?)\n^\k<i1>end[ \t]*$/m

      SOURCE_BLOCK_CALL = /^(?<i1>[ \t]*)source\(?[ \t]*(?<src>#{STRING})[ \t]*\)?[ \t]+do[ \t]*?\n(?<blk>.*?)\n^\k<i1>end[ \t]*$/m

      SOURCE_CALL = /^[ \t]*source\(?[ \t]*(?<src>#{STRING})[ \t]*\)?/

      GEMSPEC_CALL = /^[ \t]*gemspec(?:\(?[ \t]*(?<opts>#{OPTIONS}))?[ \t]*\)?[ \t]*$/

      ADD_DEPENDENCY_CALL = /^[ \t]*\w+\.add(?<type>_runtime|_development)?_dependency\(?[ \t]*(?<qname>#{QUOTED_GEM_NAME})(?:[ \t]*,[ \t]*(?<reqall>(?<rso>\[)?[ \t]*#{REQUIREMENT_LIST}(?<rsc>\])?))?.*$/

      def self.options(string)
        {}.tap do |hash|
          return hash unless string
          pairs = Hash[*string.match(OPTIONS).captures.compact]
          pairs.each{|k,v| hash[key(k)] = value(v) }
        end
      end

      def self.key(string)
        string.tr(%(:"'), "")
      end

      def self.value(string)
        case string
        when ARRAY then values(string.tr("[]", ""))
        when SYMBOL then string.tr(%(:"'), "").to_sym
        when STRING then string.tr(%("'), "")
        when BOOLEAN then string == "true"
        when NIL then nil
        end
      end

      def self.values(string)
        string.strip.split(/[ \t]*,[ \t]*/).map{|v| value(v) }
      end
    end
  end
end
