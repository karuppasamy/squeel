module Arel #:nodoc: all

  class Table
    alias :table_name :name

    def [] name
      ::Arel::Attribute.new self, name.to_sym
    end
  end

  module Nodes
    class Node
      def not
        Nodes::Not.new self
      end
    end

    remove_const :And
    class And < Arel::Nodes::Node
      attr_reader :children

      def initialize children, right = nil
        unless Array === children
          children = [children, right]
        end
        @children = children
      end

      def left
        children.first
      end

      def right
        children[1]
      end
    end

    class NamedFunction < Arel::Nodes::Function
      attr_accessor :name, :distinct

      include Arel::Predications

      def initialize name, expr, aliaz = nil
        super(expr, aliaz)
        @name = name
        @distinct = false
      end
    end

    class InfixOperation < Binary
      include Arel::Expressions
      include Arel::Predications

      attr_reader :operator

      def initialize operator, left, right
        super(left, right)
        @operator = operator
      end
    end

    class Multiplication < InfixOperation
      def initialize left, right
        super(:*, left, right)
      end
    end

    class Division < InfixOperation
      def initialize left, right
        super(:/, left, right)
      end
    end

    class Addition < InfixOperation
      def initialize left, right
        super(:+, left, right)
      end
    end

    class Subtraction < InfixOperation
      def initialize left, right
        super(:-, left, right)
      end
    end
  end

  module Visitors
    class ToSql
      def column_for attr
        name    = attr.name.to_s
        table   = attr.relation.table_name

        column_cache[table][name]
      end

      # This isn't really very cachey at all. Good enough for now.
      def column_cache
        @column_cache ||= Hash.new do |hash, key|
          Hash[
            @engine.connection.columns(key, "#{key} Columns").map do |c|
              [c.name, c]
            end
          ]
        end
      end

      def visit_Arel_Nodes_InfixOperation o
        "#{visit o.left} #{o.operator} #{visit o.right}"
      end

      def visit_Arel_Nodes_NamedFunction o
        "#{o.name}(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
          visit x
        }.join(', ')})#{o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_And o
        o.children.map { |x| visit x }.join ' AND '
      end

      def visit_Arel_Nodes_Not o
        "NOT (#{visit o.expr})"
      end

      def visit_Arel_Nodes_Values o
        "VALUES (#{o.expressions.zip(o.columns).map { |value, attr|
          if Nodes::SqlLiteral === value
            visit_Arel_Nodes_SqlLiteral value
          else
            quote(value, attr && column_for(attr))
          end
        }.join ', '})"
      end
    end
  end

  module Predications
    def as other
      Nodes::As.new self, Nodes::SqlLiteral.new(other)
    end
  end

end