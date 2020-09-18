module Steep
  class Typing
    class DeclarationIndex
      class Entry
        attr_reader :module_name
        attr_reader :nodes
        attr_reader :decls

        def initialize(module_name:)
          @module_name = module_name
          @nodes = Set[].compare_by_identity
          @decls = Set[]
        end

        def ==(other)
          other.is_a?(Entry) &&
            other.module_name == module_name &&
            other.nodes == nodes &&
            other.decls == decls
        end

        alias eql? ==

        def hash
          module_name.hash ^ nodes.hash ^ decls.hash
        end

        def merge!(other)
          nodes.merge(other.nodes)
          decls.merge(other.decls)
        end

        def merge(other)
          Entry.new(module_name).tap do |entry|
            entry.merge!(other)
          end
        end
      end

      attr_reader :source

      attr_reader :parent
      attr_reader :count
      attr_reader :parent_count

      attr_reader :entries
      attr_reader :node_to_entry
      attr_reader :decl_to_entry

      def initialize(source:, parent: nil)
        @source = source
        @parent = parent

        @count = parent&.count || 0
        @parent_count = parent&.count

        @entries = {}
        @node_to_decl = {}.compare_by_identity
        @decl_to_node = {}
      end

      def new_child
        DeclarationIndex.new(source: source, parent: self)
      end

      def merge!(child)
        unless child.parent == self
          raise "merge! with other parent"
        end

        unless child.parent_count == count
          raise "Changed after new_child"
        end

        entries.merge!(child.entries) do |_, parent_entry, child_entry|
          parent_entry.merge!(child_entry)
        end

        node_to_entry.merge!(child.node_to_entry) do |_, parent_set, child_set|
          parent_set.merge(child_set)
        end

        decl_to_entry(child.decl_to_entry) do |_, parent_set, child_set|
          parent_set.merge(child_set)
        end

        @count = child.count
      end

      def entry(node: nil, decl: nil)
        if node
          entry = node_to_entry[node]
        end

        if decl
          entry = decl_to_entry[decl]
        end

        if parent
          parent_entry = parent.entry(node: node, decl: decl)

          if parent_entry
            entry = entry.merge(parent_entry)
          end
        end

        entry
      end

      def add(module_name, node: nil, decl: nil)
        @count += 1

        entry = (entries[module_name] ||= Entry.new(module_name: module_name))

        if node
          entry.nodes << node
          (node_to_entry[node] ||= Set[]) << entry
        end

        if decl
          entry.decls << decl
          (decl_to_entry[decl] ||= Set[]) << entry
        end
      end
    end
  end
end
