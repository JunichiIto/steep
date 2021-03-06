module Steep
  module AST
    module Types
      class Factory
        attr_reader :definition_builder

        attr_reader :type_name_cache
        attr_reader :type_cache

        def initialize(builder:)
          @definition_builder = builder

          @type_name_cache = {}
          @type_cache = {}
        end

        def type_name_resolver
          @type_name_resolver ||= RBS::TypeNameResolver.from_env(definition_builder.env)
        end

        def type(type)
          ty = type_cache[type] and return ty

          type_cache[type] = case type
          when RBS::Types::Bases::Any
            Any.new(location: nil)
          when RBS::Types::Bases::Class
            Class.new(location: nil)
          when RBS::Types::Bases::Instance
            Instance.new(location: nil)
          when RBS::Types::Bases::Self
            Self.new(location: nil)
          when RBS::Types::Bases::Top
            Top.new(location: nil)
          when RBS::Types::Bases::Bottom
            Bot.new(location: nil)
          when RBS::Types::Bases::Bool
            Boolean.new(location: nil)
          when RBS::Types::Bases::Void
            Void.new(location: nil)
          when RBS::Types::Bases::Nil
            Nil.new(location: nil)
          when RBS::Types::Variable
            Var.new(name: type.name, location: nil)
          when RBS::Types::ClassSingleton
            type_name = type.name
            Name::Singleton.new(name: type_name, location: nil)
          when RBS::Types::ClassInstance
            type_name = type.name
            args = type.args.map {|arg| type(arg) }
            Name::Instance.new(name: type_name, args: args, location: nil)
          when RBS::Types::Interface
            type_name = type.name
            args = type.args.map {|arg| type(arg) }
            Name::Interface.new(name: type_name, args: args, location: nil)
          when RBS::Types::Alias
            type_name = type.name
            Name::Alias.new(name: type_name, args: [], location: nil)
          when RBS::Types::Union
            Union.build(types: type.types.map {|ty| type(ty) }, location: nil)
          when RBS::Types::Intersection
            Intersection.build(types: type.types.map {|ty| type(ty) }, location: nil)
          when RBS::Types::Optional
            Union.build(types: [type(type.type), Nil.new(location: nil)], location: nil)
          when RBS::Types::Literal
            Literal.new(value: type.literal, location: nil)
          when RBS::Types::Tuple
            Tuple.new(types: type.types.map {|ty| type(ty) }, location: nil)
          when RBS::Types::Record
            elements = type.fields.each.with_object({}) do |(key, value), hash|
              hash[key] = type(value)
            end
            Record.new(elements: elements, location: nil)
          when RBS::Types::Proc
            params = params(type.type)
            return_type = type(type.type.return_type)
            Proc.new(params: params, return_type: return_type, location: nil)
          else
            raise "Unexpected type given: #{type}"
          end
        end

        def type_1(type)
          case type
          when Any
            RBS::Types::Bases::Any.new(location: nil)
          when Class
            RBS::Types::Bases::Class.new(location: nil)
          when Instance
            RBS::Types::Bases::Instance.new(location: nil)
          when Self
            RBS::Types::Bases::Self.new(location: nil)
          when Top
            RBS::Types::Bases::Top.new(location: nil)
          when Bot
            RBS::Types::Bases::Bottom.new(location: nil)
          when Boolean
            RBS::Types::Bases::Bool.new(location: nil)
          when Void
            RBS::Types::Bases::Void.new(location: nil)
          when Nil
            RBS::Types::Bases::Nil.new(location: nil)
          when Var
            RBS::Types::Variable.new(name: type.name, location: nil)
          when Name::Singleton
            RBS::Types::ClassSingleton.new(name: type.name, location: nil)
          when Name::Instance
            RBS::Types::ClassInstance.new(
              name: type.name,
              args: type.args.map {|arg| type_1(arg) },
              location: nil
            )
          when Name::Interface
            RBS::Types::Interface.new(
              name: type.name,
              args: type.args.map {|arg| type_1(arg) },
              location: nil
            )
          when Name::Alias
            type.args.empty? or raise "alias type with args is not supported"
            RBS::Types::Alias.new(name: type.name, location: nil)
          when Union
            RBS::Types::Union.new(
              types: type.types.map {|ty| type_1(ty) },
              location: nil
            )
          when Intersection
            RBS::Types::Intersection.new(
              types: type.types.map {|ty| type_1(ty) },
              location: nil
            )
          when Literal
            RBS::Types::Literal.new(literal: type.value, location: nil)
          when Tuple
            RBS::Types::Tuple.new(
              types: type.types.map {|ty| type_1(ty) },
              location: nil
            )
          when Record
            fields = type.elements.each.with_object({}) do |(key, value), hash|
              hash[key] = type_1(value)
            end
            RBS::Types::Record.new(fields: fields, location: nil)
          when Proc
            RBS::Types::Proc.new(
              type: function_1(type.params, type.return_type),
              location: nil
            )
          else
            raise "Unexpected type given: #{type} (#{type.class})"
          end
        end

        def function_1(params, return_type)
          RBS::Types::Function.new(
            required_positionals: params.required.map {|type| RBS::Types::Function::Param.new(name: nil, type: type_1(type)) },
            optional_positionals: params.optional.map {|type| RBS::Types::Function::Param.new(name: nil, type: type_1(type)) },
            rest_positionals: params.rest&.yield_self {|type| RBS::Types::Function::Param.new(name: nil, type: type_1(type)) },
            trailing_positionals: [],
            required_keywords: params.required_keywords.transform_values {|type| RBS::Types::Function::Param.new(name: nil, type: type_1(type)) },
            optional_keywords: params.optional_keywords.transform_values {|type| RBS::Types::Function::Param.new(name: nil, type: type_1(type)) },
            rest_keywords: params.rest_keywords&.yield_self {|type| RBS::Types::Function::Param.new(name: nil, type: type_1(type)) },
            return_type: type_1(return_type)
          )
        end

        def params(type)
          Interface::Params.new(
            required: type.required_positionals.map {|param| type(param.type) },
            optional: type.optional_positionals.map {|param| type(param.type) },
            rest: type.rest_positionals&.yield_self {|param| type(param.type) },
            required_keywords: type.required_keywords.transform_values {|param| type(param.type) },
            optional_keywords: type.optional_keywords.transform_values {|param| type(param.type) },
            rest_keywords: type.rest_keywords&.yield_self {|param| type(param.type) }
          )
        end

        def method_type(method_type, self_type:, subst2: nil, method_def: nil)
          fvs = self_type.free_variables()

          type_params = []
          alpha_vars = []
          alpha_types = []

          method_type.type_params.map do |name|
            if fvs.include?(name)
              type = Types::Var.fresh(name)
              alpha_vars << name
              alpha_types << type
              type_params << type.name
            else
              type_params << name
            end
          end
          subst = Interface::Substitution.build(alpha_vars, alpha_types)
          subst.merge!(subst2, overwrite: true) if subst2

          type = Interface::MethodType.new(
            type_params: type_params,
            return_type: type(method_type.type.return_type).subst(subst),
            params: params(method_type.type).subst(subst),
            block: method_type.block&.yield_self do |block|
              Interface::Block.new(
                optional: !block.required,
                type: Proc.new(params: params(block.type).subst(subst),
                               return_type: type(block.type.return_type).subst(subst), location: nil)
              )
            end,
            method_def: method_def,
            location: method_def&.member&.location
          )

          if block_given?
            yield type
          else
            type
          end
        end

        def method_type_1(method_type, self_type:)
          fvs = self_type.free_variables()

          type_params = []
          alpha_vars = []
          alpha_types = []

          method_type.type_params.map do |name|
            if fvs.include?(name)
              type = RBS::Types::Variable.new(name: name, location: nil),
              alpha_vars << name
              alpha_types << type
              type_params << type.name
            else
              type_params << name
            end
          end
          subst = Interface::Substitution.build(alpha_vars, alpha_types)

          type = RBS::MethodType.new(
            type_params: type_params,
            type: function_1(method_type.params.subst(subst), method_type.return_type.subst(subst)),
            block: method_type.block&.yield_self do |block|
              block_type = block.type.subst(subst)

              RBS::MethodType::Block.new(
                type: function_1(block_type.params, block_type.return_type),
                required: !block.optional
              )
            end,
            location: nil
          )

          if block_given?
            yield type
          else
            type
          end
        end

        class InterfaceCalculationError < StandardError
          attr_reader :type

          def initialize(type:, message:)
            @type = type
            super message
          end
        end

        def unfold(type_name)
          type_name.yield_self do |type_name|
            type(definition_builder.expand_alias(type_name))
          end
        end

        def expand_alias(type)
          unfolded = case type
                     when AST::Types::Name::Alias
                       unfold(type.name)
                     else
                       type
                     end

          if block_given?
            yield unfolded
          else
            unfolded
          end
        end

        def deep_expand_alias(type, recursive: Set.new, &block)
          raise "Recursive type definition: #{type}" if recursive.member?(type)

          ty = case type
               when AST::Types::Name::Alias
                 deep_expand_alias(expand_alias(type), recursive: recursive.union([type]))
               when AST::Types::Union
                 AST::Types::Union.build(
                   types: type.types.map {|ty| deep_expand_alias(ty, recursive: recursive, &block) },
                   location: type.location
                 )
               else
                 type
               end

          if block_given?
            yield ty
          else
            ty
          end
        end

        def flatten_union(type, acc = [])
          case type
          when AST::Types::Union
            type.types.each {|ty| flatten_union(ty, acc) }
          else
            acc << type
          end

          acc
        end

        def unwrap_optional(type)
          case type
          when AST::Types::Union
            falsy_types, truthy_types = type.types.partition do |type|
              (type.is_a?(AST::Types::Literal) && type.value == false) ||
                type.is_a?(AST::Types::Nil)
            end

            [
              AST::Types::Union.build(types: truthy_types),
              AST::Types::Union.build(types: falsy_types)
            ]
          when AST::Types::Name::Alias
            unwrap_optional(expand_alias(type))
          else
            [type, nil]
          end
        end

        def setup_primitives(method_name, method_type)
          if method_def = method_type.method_def
            defined_in = method_def.defined_in
            member = method_def.member

            case
            when defined_in == RBS::BuiltinNames::Object.name && member.instance?
              case method_name
              when :is_a?, :kind_of?, :instance_of?
                return method_type.with(
                  return_type: AST::Types::Logic::ReceiverIsArg.new(location: method_type.return_type.location)
                )
              when :nil?
                return method_type.with(
                  return_type: AST::Types::Logic::ReceiverIsNil.new(location: method_type.return_type.location)
                )
              end

            when defined_in == AST::Builtin::NilClass.module_name && member.instance?
              case method_name
              when :nil?
                return method_type.with(
                  return_type: AST::Types::Logic::ReceiverIsNil.new(location: method_type.return_type.location)
                )
              end

            when defined_in == RBS::BuiltinNames::BasicObject.name && member.instance?
              case method_name
              when :!
                return method_type.with(
                  return_type: AST::Types::Logic::Not.new(location: method_type.return_type.location)
                )
              end

            when defined_in == RBS::BuiltinNames::Module.name && member.instance?
              case method_name
              when :===
                return method_type.with(
                  return_type: AST::Types::Logic::ArgIsReceiver.new(location: method_type.return_type.location)
                )
              end
            end
          end

          method_type
        end

        def interface(type, private:, self_type: type)
          Steep.logger.debug { "Factory#interface: #{type}, private=#{private}, self_type=#{self_type}" }
          type = expand_alias(type)

          case type
          when Self
            if self_type != type
              interface self_type, private: private, self_type: Self.new
            else
              raise "Unexpected `self` type interface"
            end
          when Name::Instance
            Interface::Interface.new(type: self_type, private: private).tap do |interface|
              definition = definition_builder.build_instance(type.name)

              instance_type = Name::Instance.new(name: type.name,
                                                 args: type.args.map { Any.new(location: nil) },
                                                 location: nil)
              module_type = type.to_module()

              subst = Interface::Substitution.build(
                definition.type_params,
                type.args,
                instance_type: instance_type,
                module_type: module_type,
                self_type: self_type
              )

              definition.methods.each do |name, method|
                Steep.logger.tagged "method = #{name}" do
                  next if method.private? && !private

                  interface.methods[name] = Interface::Interface::Entry.new(
                    method_types: method.defs.map do |type_def|
                      setup_primitives(
                        name,
                        method_type(type_def.type,
                                    method_def: type_def,
                                    self_type: self_type,
                                    subst2: subst)
                      )
                    end
                  )
                end
              end
            end

          when Name::Interface
            Interface::Interface.new(type: self_type, private: private).tap do |interface|
              type_name = type.name
              definition = definition_builder.build_interface(type_name)

              subst = Interface::Substitution.build(
                definition.type_params,
                type.args,
                self_type: self_type
              )

              definition.methods.each do |name, method|
                interface.methods[name] = Interface::Interface::Entry.new(
                  method_types: method.defs.map do |type_def|
                    method_type(type_def.type, method_def: type_def, self_type: self_type, subst2: subst)
                  end
                )
              end
            end

          when Name::Singleton
            Interface::Interface.new(type: self_type, private: private).tap do |interface|
              definition = definition_builder.build_singleton(type.name)

              instance_type = Name::Instance.new(name: type.name,
                                                 args: definition.type_params.map {Any.new(location: nil)},
                                                 location: nil)
              subst = Interface::Substitution.build(
                [],
                instance_type: instance_type,
                module_type: type,
                self_type: self_type
              )

              definition.methods.each do |name, method|
                next if !private && method.private?

                interface.methods[name] = Interface::Interface::Entry.new(
                  method_types: method.defs.map do |type_def|
                    setup_primitives(
                      name,
                      method_type(type_def.type,
                                  method_def: type_def,
                                  self_type: self_type,
                                  subst2: subst)
                    )
                  end
                )
              end
            end

          when Literal
            interface type.back_type, private: private, self_type: self_type

          when Nil
            interface Builtin::NilClass.instance_type, private: private, self_type: self_type

          when Boolean
            interface(AST::Types::Union.build(types: [Builtin::TrueClass.instance_type, Builtin::FalseClass.instance_type]),
                      private: private,
                      self_type: self_type)

          when Union
            yield_self do
              interfaces = type.types.map {|ty| interface(ty, private: private, self_type: self_type) }
              interfaces.inject do |interface1, interface2|
                Interface::Interface.new(type: self_type, private: private).tap do |interface|
                  common_methods = Set.new(interface1.methods.keys) & Set.new(interface2.methods.keys)
                  common_methods.each do |name|
                    types1 = interface1.methods[name].method_types
                    types2 = interface2.methods[name].method_types

                    if types1 == types2
                      interface.methods[name] = interface1.methods[name]
                    else
                      method_types = {}

                      types1.each do |type1|
                        types2.each do |type2|
                          type = type1 | type2 or next
                          method_types[type] = true
                        end
                      end

                      unless method_types.empty?
                        interface.methods[name] = Interface::Interface::Entry.new(method_types: method_types.keys)
                      end
                    end
                  end
                end
              end
            end

          when Intersection
            yield_self do
              interfaces = type.types.map {|ty| interface(ty, private: private, self_type: self_type) }
              interfaces.inject do |interface1, interface2|
                Interface::Interface.new(type: self_type, private: private).tap do |interface|
                  interface.methods.merge!(interface1.methods)
                  interface.methods.merge!(interface2.methods)
                end
              end
            end

          when Tuple
            yield_self do
              element_type = Union.build(types: type.types, location: nil)
              array_type = Builtin::Array.instance_type(element_type)
              interface(array_type, private: private, self_type: self_type).tap do |array_interface|
                array_interface.methods[:[]] = array_interface.methods[:[]].yield_self do |aref|
                  Interface::Interface::Entry.new(
                    method_types: type.types.map.with_index {|elem_type, index|
                      Interface::MethodType.new(
                        type_params: [],
                        params: Interface::Params.new(required: [AST::Types::Literal.new(value: index)],
                                                      optional: [],
                                                      rest: nil,
                                                      required_keywords: {},
                                                      optional_keywords: {},
                                                      rest_keywords: nil),
                        block: nil,
                        return_type: elem_type,
                        method_def: nil,
                        location: nil
                      )
                    } + aref.method_types
                  )
                end

                array_interface.methods[:[]=] = array_interface.methods[:[]=].yield_self do |update|
                  Interface::Interface::Entry.new(
                    method_types: type.types.map.with_index {|elem_type, index|
                      Interface::MethodType.new(
                        type_params: [],
                        params: Interface::Params.new(required: [AST::Types::Literal.new(value: index), elem_type],
                                                      optional: [],
                                                      rest: nil,
                                                      required_keywords: {},
                                                      optional_keywords: {},
                                                      rest_keywords: nil),
                        block: nil,
                        return_type: elem_type,
                        method_def: nil,
                        location: nil
                      )
                    } + update.method_types
                  )
                end

                array_interface.methods[:first] = array_interface.methods[:first].yield_self do |first|
                  Interface::Interface::Entry.new(
                    method_types: [
                      Interface::MethodType.new(
                        type_params: [],
                        params: Interface::Params.empty,
                        block: nil,
                        return_type: type.types[0] || AST::Builtin.nil_type,
                        method_def: nil,
                        location: nil
                      )
                    ]
                  )
                end

                array_interface.methods[:last] = array_interface.methods[:last].yield_self do |last|
                  Interface::Interface::Entry.new(
                    method_types: [
                      Interface::MethodType.new(
                        type_params: [],
                        params: Interface::Params.empty,
                        block: nil,
                        return_type: type.types.last || AST::Builtin.nil_type,
                        method_def: nil,
                        location: nil
                      )
                    ]
                  )
                end
              end
            end

          when Record
            yield_self do
              key_type = type.elements.keys.map {|value| Literal.new(value: value, location: nil) }.yield_self do |types|
                Union.build(types: types, location: nil)
              end
              value_type = Union.build(types: type.elements.values, location: nil)
              hash_type = Builtin::Hash.instance_type(key_type, value_type)

              interface(hash_type, private: private, self_type: self_type).tap do |hash_interface|
                hash_interface.methods[:[]] = hash_interface.methods[:[]].yield_self do |ref|
                  Interface::Interface::Entry.new(
                    method_types: type.elements.map {|key_value, value_type|
                      key_type = Literal.new(value: key_value, location: nil)
                      Interface::MethodType.new(
                        type_params: [],
                        params: Interface::Params.new(required: [key_type],
                                                      optional: [],
                                                      rest: nil,
                                                      required_keywords: {},
                                                      optional_keywords: {},
                                                      rest_keywords: nil),
                        block: nil,
                        return_type: value_type,
                        method_def: nil,
                        location: nil
                      )
                    } + ref.method_types
                  )
                end

                hash_interface.methods[:[]=] = hash_interface.methods[:[]=].yield_self do |update|
                  Interface::Interface::Entry.new(
                    method_types: type.elements.map {|key_value, value_type|
                      key_type = Literal.new(value: key_value, location: nil)
                      Interface::MethodType.new(
                        type_params: [],
                        params: Interface::Params.new(required: [key_type, value_type],
                                                      optional: [],
                                                      rest: nil,
                                                      required_keywords: {},
                                                      optional_keywords: {},
                                                      rest_keywords: nil),
                        block: nil,
                        return_type: value_type,
                        method_def: nil,
                        location: nil
                      )
                    } + update.method_types
                  )
                end
              end
            end

          when Proc
            interface(Builtin::Proc.instance_type, private: private, self_type: self_type).tap do |interface|
              method_type = Interface::MethodType.new(
                type_params: [],
                params: type.params,
                return_type: type.return_type,
                block: nil,
                method_def: nil,
                location: nil
              )

              interface.methods[:[]] = Interface::Interface::Entry.new(method_types: [method_type])
              interface.methods[:call] = Interface::Interface::Entry.new(method_types: [method_type])
            end

          when Logic::Base
            interface(AST::Builtin.bool_type, private: private, self_type: self_type)

          else
            raise "Unexpected type for interface: #{type}"
          end
        end

        def module_name?(type_name)
          entry = env.class_decls[type_name] and entry.is_a?(RBS::Environment::ModuleEntry)
        end

        def class_name?(type_name)
          entry = env.class_decls[type_name] and entry.is_a?(RBS::Environment::ClassEntry)
        end

        def env
          @env ||= definition_builder.env
        end

        def absolute_type(type, namespace:)
          absolute_type = type_1(type).map_type_name do |name|
            absolute_type_name(name, namespace: namespace) || name.absolute!
          end
          type(absolute_type)
        end

        def absolute_type_name(type_name, namespace:)
          type_name_resolver.resolve(type_name, context: namespace.ascend)
        end

        def instance_type(type_name, args: nil, location: nil)
          raise unless type_name.class?

          definition = definition_builder.build_singleton(type_name)
          def_args = definition.type_params.map { Any.new(location: nil) }

          if args
            raise if def_args.size != args.size
          else
            args = def_args
          end

          AST::Types::Name::Instance.new(location: location, name: type_name, args: args)
        end
      end
    end
  end
end
